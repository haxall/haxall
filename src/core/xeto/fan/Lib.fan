//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

**
** Versioned library module of specs and defs.
** Use `XetoEnv.lib` to load libraries.
**
@Js
const mixin Lib : Spec
{

  ** Version of this library
  abstract Version version()

  ** List the dependencies
  abstract LibDepend[] depends()

  ** Lookup a type in this library by name.
  @NoDoc abstract Spec? libType(Str name, Bool checked := true)

}

**************************************************************************
** LibDepend
**************************************************************************

**
** Xeto library dependency
**
@Js
const mixin LibDepend
{
  ** Qualified name of library dependency
  abstract Str qname()

  ** Version constraints that satisify this dependency
  abstract LibDependVersions versions()

  ** String representation is "<qname> <versions>"
  abstract override Str toStr()
}

**************************************************************************
** LibDependVersions
**************************************************************************

**
** Xeto library dependency version constraints
**
@Js
const mixin LibDependVersions
{
  ** Parse string representation
  static new fromStr(Str s, Bool checked := true) { XetoEnv.cur.parseLibDependVersions(s, checked) }

  ** Return if the given version satisifies this instance's constraints
  abstract Bool contains(Version version)
}

