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
const class FileExt : ExtObj, IFileExt
{
  new make()
  {
  }

  ** Get the root of the filesystem
  virtual once DynamicMount root() { RootMount(this) }

  ** Get file access control for the given mount
  virtual FileAccess fileAccess(Mount mount) { FileAccess(mount) }

  ** Resolve the uri in the filesystem.
  override File resolve(Uri uri) { MountFile(uri) }
}

**************************************************************************
** HxRootMount
**************************************************************************

internal const class RootMount : DynamicMount
{
  new make(FileExt ext) : super(ext, Etc.dict1("mountPoint", `/`))
  {
    this.mounts = [
      ioMount,
      libMount,
      podMount,
      recMount,
    ]
  }

  private LocalMount ioMount()
  {
    LocalMount(ext, Etc.dict3(
      "mountPoint", `/io/`,
      "localPath",   rt.dir.plus(`io/`).uri,
      "frozen",      Marker.val
    ))
  }

  private LibMount libMount()
  {
    LibMount(ext, Etc.dict2(
      "mountPoint", `/lib/`,
      "frozen",     Marker.val
    ))
  }

  private PodMount podMount()
  {
    PodMount(ext, Etc.dict2(
      "mountPoint", `/pod/`,
      "frozen",     Marker.val
    ))
  }

  private RecMount recMount()
  {
    RecMount(ext, Etc.dict2(
      "mountPoint", `/rec/`,
      "frozen",     Marker.val
    ))
  }

  override const Mount[] mounts

  override Mount? resolveSubmount(Uri uri)
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