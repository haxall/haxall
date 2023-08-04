//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util

**
** Versioned library module of specs and defs.
** Use `XetoEnv.lib` to load libraries.
**
@Js
const mixin Lib
{

  ** Dotted name of the library
  abstract Str name()

  ** Meta data for library
  abstract Dict meta()

  ** Version of this library
  abstract Version version()

  ** List the dependencies
  abstract LibDepend[] depends()

  ** List the top level types
  abstract Spec[] types()

  ** Lookup a top level type spec in this library by simple name
  abstract Spec? type(Str name, Bool checked := true)

  ** List the instance data dicts declared in this library
  abstract Dict[] instances()

  ** Lookup an instance dict by its simple name
  abstract Dict? instance(Str name, Bool checked := true)

  ** Environment for lib
  @NoDoc abstract XetoEnv env()

  ** File location of definition or unknown
  @NoDoc abstract FileLoc loc()

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
  ** Library name of dependency
  abstract Str name()

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

