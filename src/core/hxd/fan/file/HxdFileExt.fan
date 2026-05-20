//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2021  Brian Frank  Creation
//   22 Aug 2025  Brian Frank  Garden City (refactor for 4.0)
//

using concurrent
using web
using xeto
using haystack
using hx
using hxm
using hxFolio
using util

**
** Haxall daemon simple implementation for file extension
** with support for the following virtual namespaces:
**  - `rec/`: files stored as recs in folio backed by file system
**  - `lib/`: xeto lib files
**  - `io/`: proj io/ directory
**
internal const class HxdFileExt : HxFileExt
{
  new make()
  {
  }

  override const HxdRootMount root := HxdRootMount(this)

  override UploadHandler uploadHandler(WebReq req, WebRes res, Dict opts)
  {
    FileUploadHandler(req, res, opts)
  }
}

**************************************************************************
** HxdRootMount
**************************************************************************

internal const class HxdRootMount : HxDynamicMount
{
  new make(HxFileExt ext) : super(ext, Etc.dict1("mountPath", `/`))
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
