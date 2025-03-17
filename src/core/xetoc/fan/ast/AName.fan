//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Feb 2023  Brian Frank  Creation
//    3 Jul 2023  Brian Frank  Redesign the AST
//

using util

**
** AST relative or qualified name
**
internal abstract const class AName
{
  ** Constructor
  new make(Str? lib) { this.lib = lib }

  ** Is this a qualified name
  Bool isQualified() { lib != null }

  ** Library name if qualified or null if unknown
  const Str? lib

  ** Is this a dotted name path
  abstract Bool isPath()

  ** Simple name or last name if path
  abstract Str name()

  ** Number of names if path or one if simple name
  abstract Int size()

  ** Name at path level for dotted paths
  abstract Str nameAt(Int index)

}

**************************************************************************
** ASimpleName
**************************************************************************

internal const class ASimpleName : AName
{
  new make(Str? lib, Str name)  : super(lib)
  {
    if (name.isEmpty) throw ArgErr("${lib?.toCode} $name.toCode")
    this.name = name
  }

  override Bool isPath() { false }

  override const Str name

  override Int size() { 1 }

  override Str nameAt(Int i)
  {
    if (i == 0) return name
    throw IndexErr(i.toStr)
  }

  override Str toStr()
  {
    isQualified ? "$lib::$name" : name
  }
}

**************************************************************************
** APathName
**************************************************************************

internal const class APathName  : AName
{
  new make(Str? lib, Str[] path) : super(lib)
  {
    this.path = path
  }

  const Str[] path

  override Bool isPath() { true }

  override Str name() { encode(false) }

  override Int size() { path.size }

  override Str nameAt(Int i) { path[i] }

  override Str toStr() { encode(isQualified) }

  private Str encode(Bool qname)
  {
    s := StrBuf()
    if (qname) s.add(lib).add("::")
    path.each |n, i| { if (i > 0) s.addChar('.'); s.add(n) }
    return s.toStr
  }
}

