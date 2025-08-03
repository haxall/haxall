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
// Fantom
//////////////////////////////////////////////////////////////////////////

  static Void scanFantom(Ast ast, AExt ext, File file)
  {
    typeName := file.basename
    ext.fantomFuncType = typeName
    qname := ext.pod.name + "::" + typeName

    type := Type.find(qname)
    type.methods.each |m|
    {
      if (!m.isPublic) return
      if (m.parent !== type) return
      facet := m.facet(Axon#, false) as Axon
      if (facet == null) return

      meta := Str:Obj[:]
      facet.decode |n, v| { meta[n] = v }
      metaDict := Etc.dictFromMap(meta)

      ext.funcs.add(reflectMethod(m, metaDict))
    }
  }

  static AFunc reflectMethod(Method method, Dict metaDict)
  {
    // lookup method by name or _name
    name := method.name
    if (name[0] == '_') name = name[1..-1]

    doc := method.doc

    // meta
    meta := Str:Obj[:]
    metaDict.each |v, n|
    {
      // skip these
      if (n == "def")  return
      if (n == "lib")  return
      if (n == "is")   return
      if (n == "func") return
      if (n == "name") return
      if (n == "haystackApi") return
      if (n == "refresh") return
      if (n == "actionNew") return
      if (n.endsWith("_enum")) return
      if (n.startsWith("trio_")) return

      if (n == "doc")  { doc = v; return }

      // ui actions - handled below
      if (n == "select") return
      if (n == "multi") return

      // special handling to map fro ui -> ion
      if (n == "dis")
      {
        n = "text"
      }
      else if (n == "disKey")
      {
        // map disKey:"ui::x" -> text:"$<ion::x>"
        n = "text"
        v = mapMetaDisKey(v)
      }
      else if (n == "confirm")
      {
        v = mapMetaConfirm(v)
      }
      else if (n == "confirmation_placeholder")
      {
        n = "placeholder"
      }

      meta[n] = v
    }
    if (method.hasFacet(NoDoc#)) meta["nodoc"] = Marker.val
    if (method.hasFacet(Deprecated#)) meta["deprecated"] = Marker.val

    if (metaDict.has("select"))
    {
      mode := "single"
      if (metaDict.has("multi")) mode = "multi"
      meta["selectMode"] = mode
    }

    // params
    params := method.params.map |p->AParam| { reflectParam(method, p) }

    // returns
    returnType := method.returns
    if (returnType.name == "Void") returnType = Obj?#
    returns := AParam("returns", AType.map(returnType), null)

    // function stub
    return AFunc(name, doc, Etc.makeDict(meta), params, returns)
  }

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
// Class
//////////////////////////////////////////////////////////////////////////

  new makeFantom(Str name, Str doc, Dict meta, AParam[] params, AParam returns)
  {
    this.name    = name
    this.doc     = doc
    this.meta    = meta
    this.params  = params
    this.returns = returns
  }

  const Str name
  const Str doc
  const Dict meta
  const AParam[] params
  const AParam returns

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
  new make(Str name, AType type, Str? def)
  {
    this.name = name
    this.type = type
    this.def  = def
  }

  const Str name
  const AType type
  const Str? def

  override Str toStr() { "$name: $type" }
}

**************************************************************************
** AType
**************************************************************************

const class AType
{
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
    }
    return null
  }

  new make(Str sig) { this.sig = sig }

  const Str sig

  override Str toStr() { sig }
}

