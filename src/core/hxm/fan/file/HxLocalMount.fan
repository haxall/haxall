//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2026  Matthew Giannini  Creation
//

using concurrent
using util
using xeto
using haystack
using hx

**
** Mounts a local filesystem directory
**
const class HxLocalMount : HxWrapMount
{
  new make(HxFileExt ext, Dict config) : super(ext, config)
  {
    this.localRoot = ((Uri)config["localPath"]).toFile
  }

  ** Files in this mount are resolved relative to this directory
  ** on the local filsystem
  const File localRoot

  override protected File resolve(Uri uri, Str mode := "r")
  {
    file := localRoot.plus(uri)

    // sanity checks
    if (uri.toStr.contains(".."))
      throw ArgErr("Uri must not contain '..': ${uri}")
    if (!file.normalize.pathStr.startsWith(localRoot.normalize.pathStr))
      throw ArgErr("Uri not under ${localRoot}: ${uri}")

    // TODO - chokepoint for security checks
    return file
  }

  override File[] list(Uri uri)
  {
    acc := File[,]
    resolve(uri).list.each |file|
    {
      fileRel := file.uri.relTo(localRoot.uri)
      // TODO: security checks
      acc.add(ext.resolve(mountAbs(fileRel)))
    }
    return acc
  }
}

