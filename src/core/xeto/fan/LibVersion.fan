//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

**
** Library information models a library name and version.
**
@Js
const mixin LibVersion
{
  ** Library dotted name
  abstract Str name()

  ** Library version
  abstract Version version()

  ** Dependencies of this library
  abstract LibDepend[] depends()

  ** Summary information or empty string if not available
  abstract Str doc()

  ** File used to load this lib if backed by the file system.  If we are
  ** using the source then return the source directory, otherwise return
  ** the xetolib zip file found in "lib/xeto".  If the version is not backed
  ** by a file then raise exception or return null based on checked flag.
  @NoDoc abstract File? file(Bool checked := true)

}

