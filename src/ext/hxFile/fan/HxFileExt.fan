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
** Exposes a virtual filesystem for Haxall.
**
const class HxFileExt : ExtObj, IFileExt
{
  new make()
  {
  }

  ** Get the root of the filesystem
  virtual once HxDynamicMount root() { HxRootMount(this) }

  ** Get file access control for the given mount
  virtual HxFileAccess fileAccess(HxMount mount) { HxFileAccess(mount) }

  ** Resolve the uri in the filesystem.
  override File resolve(Uri uri) { HxMountFile(uri) }
}

**************************************************************************
** HxRootMount
**************************************************************************

internal const class HxRootMount : HxDynamicMount
{
  new make(HxFileExt ext) : super(ext, Etc.dict1("mountPoint", `/`))
  {
    this.mounts = [
      ioMount,
      libMount,
      podMount,
      recMount,
    ]
  }

  private HxLocalMount ioMount()
  {
    HxLocalMount(ext, Etc.dict3(
      "mountPoint", `/io/`,
      "localPath",   rt.dir.plus(`io/`).uri,
      "frozen",      Marker.val
    ))
  }

  private HxLibMount libMount()
  {
    HxLibMount(ext, Etc.dict2(
      "mountPoint", `/lib/`,
      "frozen",     Marker.val
    ))
  }

  private HxPodMount podMount()
  {
    HxPodMount(ext, Etc.dict2(
      "mountPoint", `/pod/`,
      "frozen",     Marker.val
    ))
  }

  private HxRecMount recMount()
  {
    HxRecMount(ext, Etc.dict2(
      "mountPoint", `/rec/`,
      "frozen",     Marker.val
    ))
  }

  override const HxMount[] mounts

  override HxMount? resolveSubmount(Uri uri)
  {
    // force root submountes to be a dir
    if (uri.path.size == 1 && !uri.isDir) uri = uri.plusSlash

    return mounts.find |mount| { uri.pathStr.startsWith(mount.mountPoint.pathStr) }
  }

  override File[] list(Uri uri)
  {
    if (isRoot(uri)) return mounts.map |mount| { ext.resolve(`/${mount.name}/`) }

    return resolveSubmount(uri)?.list(submountRelUri(uri)) ?: File[,]
  }
}