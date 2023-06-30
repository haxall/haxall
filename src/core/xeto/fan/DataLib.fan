//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

**
** Versioned library module of data specifications.
** Use `DataEnv.lib` to load libraries.
**
@Js
const mixin DataLib : DataSpec
{

  ** Version of this library
  abstract Version version()

  ** List the dependencies
  abstract DataLibDepend[] depends()

  ** Lookup a type in this library by name.
  @NoDoc abstract DataSpec? libType(Str name, Bool checked := true)

}

**************************************************************************
** DataLibDepend
**************************************************************************

**
** Data library dependency
**
@Js
const mixin DataLibDepend
{
  ** Qualified name of library dependency
  abstract Str qname()

  ** Version constraints that satisify this dependency
  abstract DataLibDependVersions versions()

  ** String representation is "<qname> <versions>"
  abstract override Str toStr()
}

**************************************************************************
** DataLibDependVersions
**************************************************************************

**
** Data library dependency version constraints
**
@Js
const mixin DataLibDependVersions
{
  ** Parse string representation
  static new fromStr(Str s, Bool checked := true) { DataEnv.cur.parseLibDependVersions(s, checked) }

  ** Return if the given version satisifies this instance's constraints
  abstract Bool contains(Version version)
}

