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
const mixin LibInfo
{
  ** Library dotted name
  abstract Str name()

  ** Library version
  abstract Version version()

  ** Summary information or empty string if not available
  abstract Str doc()

  ** Xetolib zip file location.  This file might not exist if the source has
  ** not been built yet or the repo is not backed by the file system.  But it
  ** is always available as "lib/xeto/{name}/{name}-{version}.xetolib".
  abstract File zip()

  ** Is the source available
  abstract Bool isSrc()

  ** Source dir if available
  abstract File? src(Bool checked := true)
}

