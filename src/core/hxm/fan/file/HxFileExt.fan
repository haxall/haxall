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
abstract const class HxFileExt : ExtObj, IFileExt
{
  new make()
  {
  }

  ** Get the root of the filesystem
  abstract HxMount root()

  ** Get file access control for the given mount
  virtual HxFileAccess fileAccess(HxMount mount) { HxFileAccess(mount) }

  ** Resolve the uri in the filesystem.
  override File resolve(Uri uri) { HxMountFile(uri) }
}