//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using hx
using hxFolio

**
** HxdHisService provides simple wrapper around Folio as the
** implementation of the HxHisService.  Unlike SkySpark is does
** not currently support totalization, computed histories, etc.
**
internal const class HxdFileService : HxFileService
{
  new make(HxdRuntime rt) { this.rt = rt }

  const HxdRuntime rt

  override File resolve(Uri uri)
  {
    // pathing check
    if (uri.toStr.contains(".."))
      throw ArgErr("Uri must not contain '..' path: $uri")

    // we only support {dir}/io/xxxxx paths right now
    if (!uri.toStr.startsWith("io/"))
      throw ArgErr("Only io/ paths supportted")

    // extra directory check to ensure we don't escape out of safe io/ directory
    file := rt.dir + uri
    if (!file.normalize.pathStr.startsWith(rt.dir.normalize.pathStr))
      throw ArgErr("Uri not under ${rt.dir} dir: $uri")

    return file
  }
}

