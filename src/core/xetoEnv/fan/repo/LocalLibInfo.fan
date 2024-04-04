//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent
using xeto

**
** LibInfo implementation for LocalRepo
**
@Js
const class LocalLibInfo : LibInfo
{
  new make(Str name, Version version, File zip, File? srcDir)
  {
    this.name    = name
    this.version = version
    this.zip     = zip
    this.srcDir  = srcDir
  }

  override const Str name

  override const Version version

  override const Str doc := ""

  override const File zip

  override Bool isSrc() { srcDir != null }

  override File? src(Bool checked := true)
  {
    if (srcDir != null) return srcDir
    if (checked) throw Err("Lib source not available: $name")
    return null
  }

  override Str toStr() { "$name-$version [src: ${srcDir?.osPath}, zip: $zip.osPath]" }

  override Int compare(Obj that)
  {
    a := this
    b := (LocalLibInfo)that
    if (a.name != b.name) return a.name <=> b.name
    return a.version <=> b.version
  }

  const File? srcDir
}

