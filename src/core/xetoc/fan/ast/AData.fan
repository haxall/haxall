//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Mar 2023  Brian Frank  Creation
//   3 Jul 2023  Brian Frank  Redesign the AST
//

using util
using xeto

**
** Base class for AST data instances
**
@Js
internal abstract class AData : ANode
{
   ** Constructor
  new make(FileLoc loc, ASpecRef? type) : super(loc)
  {
    this.typeRef = type
  }

  ** Type of this data value - raise exception if not resolved yet
  CSpec type() { typeRef?.deref ?: throw NotReadyErr() }

  ** Resolved type
  ASpecRef? typeRef

  ** Assembled value - raise exception if not assembled yet
  Obj asm() { asmRef ?: throw NotReadyErr() }

  ** Is data value already assembled
  Bool isAsm() { asmRef != null }

  ** Assembled value set in Reify
  Obj? asmRef
}

**************************************************************************
** AScalar
**************************************************************************

**
** AST scalar data value
**
@Js
internal class AScalar : AData
{
  ** Constructor
  new make(FileLoc loc, ASpecRef? type, Str str, Obj? asm := null)
    : super(loc, type)
  {
    this.str     = str
    this.asmRef  = asm
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.scalar }

  ** Encoded string
  const Str str

  ** Return quoted string encoding
  override Str toStr()
  {
    typeRef != null ? "$typeRef $str.toCode" : str.toCode
  }

  ** Tree walk
  override Void walk(|ANode| f)
  {
    if (typeRef != null) typeRef.walk(f)
    f(this)
  }
}

**************************************************************************
** ADict
**************************************************************************

**
** AST dict data value (also handles lists)
**
@Js
internal class ADict : AData
{
  ** Constructor
  new make(FileLoc loc, ASpecRef? type) : super(loc, type) {}

  ** Node type
  override ANodeType nodeType() { ANodeType.dict }

  ** Identifier for this dict (not included in map)
  AName? id

  ** Is this library or spec meta
  Bool isMeta

  ** Map of dict tag name/value pairs
  Str:AData map := [:]

  ** Return quoted string encoding
  override Str toStr() { map.toStr }

  ** Convenience to get tag in map
  AData? get(Str name) { map[name] }

  ** Set value (may overwrite existing)
  Void set(Str name, AData val) { map[name] = val }

  ** Tree walk
  override Void walk(|ANode| f)
  {
    if (typeRef != null) typeRef.walk(f)
    map.each |x| { x.walk(f) }
    f(this)
  }

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    if (id != null) out.print("@").print(id).print(": ")
    if (typeRef != null) out.print(typeRef).print(" ")
    indentMore := indent + "  "
    out.printLine(isMeta ? "<" : "{")
    map.each |v, n|
    {
      out.print(indentMore).print(n).print(": ")
      v.dump(out, indentMore)
      out.printLine
    }
    out.print(indent).print(isMeta ? ">" : "}")
  }
}

