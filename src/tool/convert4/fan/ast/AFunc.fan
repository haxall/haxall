//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jul 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using axon

**
** AST axon function
**
class AFunc
{
  static Void scanExt(Ast ast, AExt ext)
  {
    // look for trio files
    ext.defs.each |def|
    {
      try
        scanDef(ast, ext, def)
      catch (Err e)
        Console.cur.err("Cannot scan def: $ext.oldName $def", e)
    }

    // look for Fantom class
    path := ext.oldName.capitalize + "Funcs.fan"
    if (ext.oldName == "axon") path = "lib/CoreLib.fan"
    if (ext.oldName == "conn") path = "ConnFwFuncs.fan"
    if (ext.oldName == "hx")   path = "HxCoreFuncs.fan"
    if (ext.oldName == "io")   path = "IOFuncs.fan"
    typeFile := ext.pod.dir + `fan/${path}`
    if (typeFile.exists)
    {
      try
        scanFantom(ast, ext, typeFile)
      catch (Err e)
        Console.cur.err("ERROR: Cannot scan Fantom axon funcs [$typeFile.osPath]", e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Defs
//////////////////////////////////////////////////////////////////////////

  static Void scanDef(Ast ast, AExt ext, Dict def)
  {
    Str? name
    if (def.has("func"))
    {
      name = def->name

    }
    else
    {
      symbol := def["def"]?.toStr
      if (symbol != null && symbol.startsWith("func:"))
        name  = symbol[5..-1]
    }
    if (name == null) return

    doc := def["doc"] as Str ?: ""
    src := def["src"] as Str ?: throw Err("Missing axon src")
    axon := ast.config.ns.io.readAxon(src)->axon

    fn := Parser(Loc.eval, src.in).parseTopWithParams(name)
    params := fn.params.map |x->AParam|
    {
      pmeta := x.def == null ? Etc.dict0 : Etc.dict1("axon", x.def.toStr)
      return AParam(x.name, AType.obj, pmeta)
    }
    returns := AParam("returns", AType.obj)

    meta := Etc.dictFromMap(mapMeta(ast, def))

    func := make(name, doc, meta, params, returns, axon)
    ext.funcs.add(func)
  }

//////////////////////////////////////////////////////////////////////////
// Fantom
//////////////////////////////////////////////////////////////////////////

  static Void scanFantom(Ast ast, AExt ext, File file)
  {
    typeName := file.basename
    ext.fantomFuncType = typeName
    qname := ext.pod.name + "::" + typeName
    type := Type.find(qname)
    scanType(ast, ext, type)
  }

  static Void scanType(Ast ast, AExt ext, Type type)
  {
    type.methods.each |m|
    {
      if (!m.isPublic) return
      if (m.parent !== type) return
      facet := m.facet(Axon#, false) as Axon
      if (facet == null) return

      meta := Str:Obj[:]
      facet.decode |n, v| { meta[n] = v }
      metaDict := Etc.dictFromMap(meta)

      ext.funcs.add(reflectMethod(ast, m, metaDict))
    }
  }

  static AFunc reflectMethod(Ast ast, Method method, Dict metaDict)
  {
    // lookup method by name or _name
    name := method.name
    if (name[0] == '_') name = name[1..-1]

    doc := metaDict["doc"] as Str ?: method.doc

    // meta
    meta := mapMeta(ast, metaDict)
    if (method.hasFacet(NoDoc#)) meta["nodoc"] = Marker.val
    if (method.hasFacet(Deprecated#)) meta["deprecated"] = Marker.val

    // params
    params := method.params.map |p->AParam| { reflectParam(method, p) }

    // returns
    returnType := method.returns
    if (returnType.name == "Void") returnType = Obj?#
    returns := AParam("returns", AType.map(returnType))

    // function stub
    return AFunc(name, doc, Etc.makeDict(meta), params, returns, null)
  }

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  static Bool isFuncMeta(Ast ast, Str n)
  {
    ast.config.funcMeta.contains(n) || ast.config.ns.metas.has(n)
  }

  static Str:Obj mapMeta(Ast ast, Dict orig)
  {
    meta := Str:Obj[:]
    defMeta := Str:Obj[:]

    orig.each |v, n|
    {
      // skip these
      if (n == "id")  return
      if (n == "def")  return
      if (n == "lib")  return
      if (n == "is")   return
      if (n == "func") return
      if (n == "name") return
      if (n == "haystackApi") return
      if (n == "refresh") return
      if (n == "doc")  return
      if (n == "src")  return
      if (n == "hisFuncReady") return

      // if its defined in axon/config; otherwise stuff into defMeta
      if (isFuncMeta(ast, n))
        meta[n] = v
      else
        defMeta[n] = v
    }

    if (!defMeta.isEmpty) meta["defMeta"] = Etc.dictFromMap(defMeta)

    return meta
  }

  /*

  static Str mapMetaDisKey(Str v)
  {
    // map disKey:"ui::x" -> text:"$<ion::x>"
    if (v.toStr.startsWith("ui::")) v = v.toStr[4..-1]
    return "\$<$v>"
  }

  static Dict mapMetaConfirm(Dict dict)
  {
    acc := Str:Obj[:]
    dict.each |v, n|
    {
      switch (n)
      {
        case "dis":        acc["text"] = v
        case "disKey":     acc["text"] = mapMetaDisKey(v)
        case "details":    acc["details"] = v
        case "detailsKey": acc["details"] = mapMetaDisKey(v)
        case "icon":       acc["icon"] = v
        case "iconColor":  acc["iconColor"] = mapMetaIconColor(v)
        default:           throw Err("Unhandled confirm key: $n: $v")
     }
    }
    return Etc.dictFromMap(acc)
  }

  static Str mapMetaIconColor(Str v)
  {
    switch (v)
    {
      case "#e67e22": return "orange"
    }
    echo("WARNING: unhandled iconColor $v.toCode")
    return "red"
  }
  */

  static AParam reflectParam(Method method, Param p)
  {
    name := p.name
    if (name == "returns") name = "_returns"

    type := p.type
    if (p.type.name == "Expr")
    {
      if (name.endsWith("Expr")) name = name[0..-5]
      if (name == "filter") type = Filter#
      else if (name == "checked") type = Bool#
      else if (name == "conn") type = Obj?#
      else if (name == "opts") type = Dict?#
      else if (name == "tagName") type = Str#
      else if (name == "target") type = Obj?#
      else if (name == "targets") type = Obj?#
      else if (name == "val") type = Obj?#
      else if (name == "locale") type = Str#
      else if (name == "expr") type = Obj?#
      else if (name == "parent") type = Obj?#
      else if (name == "scope") type = Obj?#
      else if (name == "span") type = Obj?#
      else if (name == "xq") type = Type.find("skyarcd::XQuery")
      else echo("WARN: unhandled lazy param: $method $name")
    }

    def := null // TODO

    return AParam(name, AType.map(type), def)
  }

//////////////////////////////////////////////////////////////////////////
// Func
//////////////////////////////////////////////////////////////////////////

  new make(Str name, Str doc, Dict meta, AParam[] params, AParam returns, Str? axon)
  {
    this.name    = name
    this.doc     = doc
    this.meta    = meta
    this.params  = params
    this.returns = returns
    this.axon    = axon
  }

  const Str name
  const Str doc
  const Dict meta
  const AParam[] params
  const AParam returns
  const Str? axon

  Void eachSlot(|AParam, Bool needComma| f)
  {
    comma := false
    params.each |p|
    {
      f(p, comma)
      comma = true
    }
    f(returns, comma)
  }

  override Str toStr() { name }

  Str sig()
  {
    "(" + params.join(", ") + "): " + returns.type
  }
}

**************************************************************************
** AParam
**************************************************************************

const class AParam
{
  new make(Str name, AType type, Dict meta := Etc.dict0)
  {
    this.name = name
    this.type = type
    this.meta = meta
  }

  const Str name
  const AType type
  const Dict meta

  override Str toStr() { "$name: $type" }
}

**************************************************************************
** AType
**************************************************************************

const class AType
{
  static const AType obj := AType("Obj?")

  static AType map(Type type)
  {
    // specials
    sig := mapSpecial(type.qname) ?: type.name
    if (type.isNullable) sig = sig + "?"
    return make(sig)
  }

  static Str? mapSpecial(Str qname)
  {
    switch(qname)
    {
      case "axon::Fn":           return "Func"
      case "haystack::Col":      return "Obj"
      case "haystack::Row":      return "Obj"
      case "haystack::Coord":    return "Obj"
      case "haystack::DateSpan": return "Obj"
      case "haystack::Symbol":   return "Obj"
      case "haystack::Remove":   return "Obj"
      case "haystack::Def":      return "Obj"
      case "folio::Diff":        return "Obj"
      case "axon::MStream":      return "Obj"
      case "math::Matrix":       return "Grid"
    }
    if (qname.startsWith("mlExt::")) return "Obj"
    return null
  }

  new make(Str sig) { this.sig = sig }

  const Str sig

  override Str toStr() { sig }
}

