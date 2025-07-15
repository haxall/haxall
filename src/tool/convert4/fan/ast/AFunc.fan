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
      facet := m.facet(Axon#, false)
      if (facet == null) return
      ext.funcs.add(reflectMethod(m, facet))
    }
  }

  static AFunc reflectMethod(Method method, Axon facet)
  {
    // lookup method by name or _name
    name := method.name
    if (name[0] == '_') name = name[1..-1]

    doc := method.doc

    // meta
    meta := Str:Obj[:]
    facet.decode |n, v|
    {
      meta[n] = v
    }
    if (method.hasFacet(NoDoc#)) meta["nodoc"] = Marker.val

    // params
    params := method.params.map |p->AParam| { reflectParam(method, p) }

    // returns
    returnType := method.returns
    if (returnType.name == "Void") returnType = Obj?#
    returns := AParam("returns", AType.map(returnType), null)

    // function stub
    return AFunc(name, doc, Etc.makeDict(meta), params, returns)
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
      else if (name == "opts") type = Dict?#
      else if (name == "tagName") type = Str#
      else if (name == "val") type = Obj?#
      else if (name == "locale") type = Str#
      else if (name == "expr") type = Obj?#
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
    }
    return null
  }

  new make(Str sig) { this.sig = sig }

  const Str sig

  override Str toStr() { sig }
}

