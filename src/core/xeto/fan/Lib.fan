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
**
** Lib dict representation:
**   - id: Ref "lib:{name}"
**   - spec: Ref "sys::Lib"
**   - loaded: marker tag if loaded into memory
**   - meta
**
@Js
const mixin Lib : Dict
{

  ** Return "lib:{name}" as identifier
  ** This is a temp shim until we move 'haystack::Dict' fully into Xeto.
  abstract override Ref _id()

  ** Dotted name of the library
  abstract Str name()

  ** Meta data for library
  abstract Dict meta()

  ** Version of this library
  abstract Version version()

  ** List the dependencies
  abstract LibDepend[] depends()

  ** List the top level specs (types and global slots)
  abstract Spec[] specs()

  ** Lookup a top level spec in this library by simple name (type or global slot)
  abstract Spec? spec(Str name, Bool checked := true)

  ** List the top level types
  abstract Spec[] types()

  ** Lookup a top level type spec in this library by simple name
  abstract Spec? type(Str name, Bool checked := true)

  ** List the top level global slots
  abstract Spec[] globals()

  ** Lookup a top level global slot spec in this library by simple name
  abstract Spec? global(Str name, Bool checked := true)

  ** List the instance data dicts declared in this library
  abstract Dict[] instances()

  ** Lookup an instance dict by its simple name
  abstract Dict? instance(Str name, Bool checked := true)

  ** Iterate the instances
  @NoDoc abstract Void eachInstance(|Dict| f)

  ** Is this the 'sys' library
  @NoDoc abstract Bool isSys()

  ** Does this library contain extended meta instances
  @NoDoc abstract Bool hasXMeta()

  ** File location of definition or unknown
  @NoDoc abstract FileLoc loc()

}

