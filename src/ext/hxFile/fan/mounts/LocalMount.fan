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
const class LocalMount : WrapMount
{
  new make(FileExt ext, Dict config) : super(ext, config)
  {
    this.localRoot = ((Uri)config["localPath"]).toFile
    if (!localRoot.isDir) throw ArgErr("Not a directory: ${localRoot}")
    this.localRootPath = localRoot.normalize.pathStr
  }

  ** Files in this mount are resolved relative to this directory
  ** on the local filsystem
  const File localRoot

  ** Normalized path of localRoot; File.normalize is a canonical path
  ** syscall so we compute it once instead of on every resolve
  private const Str localRootPath

  override protected File resolve(Uri uri, Str mode := "r")
  {
    file := localRoot.plus(uri)

    // sanity checks
    if (uri.toStr.contains(".."))
      throw ArgErr("Uri must not contain '..': ${uri}")
    if (!file.normalize.pathStr.startsWith(localRootPath))
      throw ArgErr("Uri not under ${localRoot}: ${uri}")

    // check access
    if (!fileAccess.allowed(uri, mode)) return nonexistent(uri)

    return file
  }

  override File[] list(Uri uri)
  {
    access := this.fileAccess
    acc := File[,]
    resolve(uri).list.each |file|
    {
      fileRel := file.uri.relTo(localRoot.uri)
      if (!access.allowed(fileRel, "r")) return
      acc.add(ext.resolve(mountAbs(fileRel)))
    }
    return acc
  }

  override Void delete(Uri uri)
  {
    if (isRoot(uri))
    {
      // do not delete localRoot itself, only its children
      localRoot.list.each |child| { child.delete }
    }
    else
    {
      super.delete(uri)
    }
  }
}

