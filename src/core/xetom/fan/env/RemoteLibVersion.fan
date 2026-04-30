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
** RemoteLibVersion is used for both RemoteEnv and RemoteRepo
**
@Js
const class RemoteLibVersion : LibVersion
{
  new make(Str name, Version version, Str doc := "", LibDepend[]? depends := null)
  {
    this.name       = name
    this.version    = version
    this.doc        = doc
    this.toStr      = "$name-$version"
    this.dependsRef = depends
  }

  override const Str name

  override const Version version

  override const Str doc

  override LibOrigin? origin(Bool checked := true)
  {
    if (checked) throw Err("No origin for '$name'")
    return null
  }

  override Int flags() { 0 } // not supported client side

  override File? file(Bool checked := true)
  {
    if (checked) throw UnsupportedErr()
    return null
  }

  override Bool isSrc() { false }

  override Bool isNotFound() { false }

  override Bool isCompanion() { name == XetoUtil.companionLibName }

  override Void eachSrcFile(|File| f) {}

  override const Str toStr

  override LibDepend[]? depends(Bool checked := true)
  {
    if (dependsRef != null) return dependsRef
    if (checked) throw UnsupportedErr("Depends not available")
    return null
  }
  const LibDepend[]? dependsRef

}

