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

**
** RemoteLibVersion
**
@Js
const class RemoteLibVersion : LibVersion
{
  new make(Str name, Version version, LibDepend[] depends)
  {
    this.name    = name
    this.version = version
    this.depends = depends
    this.toStr   = "$name-$version"
  }

  override const Str name

  override const Version version

  override Str doc() { "" }

  override Bool isSysOnly() { false }

  override File? file(Bool checked := true)
  {
    if (checked) throw UnsupportedErr()
    return null
  }

  override Bool isSrc() { false }

  override Bool isNotFound() { false }

  override Void eachSrcFile(|File| f) {}

  override const Str toStr

  override const LibDepend[] depends

}

