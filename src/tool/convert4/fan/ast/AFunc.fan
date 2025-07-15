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
    typeName := ext.oldName.capitalize + "Funcs"
    if (ext.oldName == "axon") typeName = "CoreFuncs"
    if (ext.oldName == "hx")   typeName = "HxCoreFuncs"
    if (ext.oldName == "io")   typeName = "IOFuncs"
    typeFile := ext.pod.dir + `fan/${typeName}.fan`
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
    ext.pod.fantomFuncType = typeName
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
    params := method.params.map |p->AParam|
    {
      paramName := p.name
      if (paramName == "returns") paramName = "_returns"
      paramType := AType(p.type)
      paramDef := null // TODO
      return AParam(paramName, paramType, paramDef)
    }

    // returns
    returns := AParam("returns", AType(method.returns), null)

    // function stub
    return AFunc(name, doc, Etc.makeDict(meta), params, returns)
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
  new makeType(Type type)
  {
    sig := type.name
    if (type.isNullable) sig = sig + "?"
    this.sig = sig
  }

  new make(Str sig) { this.sig = sig }

  const Str sig

  override Str toStr() { sig }
}

