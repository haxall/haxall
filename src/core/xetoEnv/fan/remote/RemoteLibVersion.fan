//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto
using haystack::UnknownLibErr

**
** RemoteLibVersion
**
@Js
internal const class RemoteLibVersion : LibVersion
{
  new make(Str name, Version version, LibDepend[] depends)
  {
    this.name    = name
    this.version = version
    this.depends = depends
  }

  override const Str name

  override const Version version

  override Str doc() { "" }

  override File? file(Bool checked := true)
  {
    if (checked) throw UnsupportedErr()
    return null
  }

  override Str toStr() { "$name-$version" }

  override const LibDepend[] depends

}

