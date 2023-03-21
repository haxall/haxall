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

  ** Lookup a type in this library by name.
  @NoDoc abstract DataType? libType(Str name, Bool checked := true)

}