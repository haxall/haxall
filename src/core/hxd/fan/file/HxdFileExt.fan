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
internal const class HxdFileExt : ExtObj, IFileExt
{
  override UploadHandler uploadHandler(WebReq req, WebRes res, Dict opts)
  {
    FileUploadHandler(req, res, opts)
  }

  override File resolve(Uri uri)
  {
    if (uri.toStr.contains("..")) throw UnsupportedErr("Uri must not contain '..' path: $uri")
    return doResolve(uri, Context.cur) ?: nonexistent(uri)
  }

  internal File? doResolve(Uri uri, Context cx)
  {
    mount := uri.path.getSafe(0)
    switch (mount)
    {
      case "io":  return resolveIo(uri, cx)
      case "rec": return resolveRec(uri, cx)
      case "lib": return resolveLib(uri, cx)
      default:    return null
    }
  }

  private File resolveIo(Uri uri, Context cx)
  {
    // extra directory check to ensure we don't escape out of safe io/ directory
    file := rt.dir + uri
    if (!file.normalize.pathStr.startsWith(rt.dir.normalize.pathStr))
      throw UnsupportedErr("Uri not under ${rt.dir} dir: $uri")

    // use a wrapper which routes everything back to here for security checks
    return HxdWrapFile(this, uri, file)
  }

  private File? resolveLib(Uri uri, Context cx)
  {
    // "/lib/{lib-name}/{file-uri}

    if (uri.path.size < 3) return null

    libName := uri.path[1]
    lib :=  cx.ns.lib(libName, false)
    if (lib == null) return null

    fileUri := uri.getRangeToPathAbs(2..-1)
    file := lib.files.get(fileUri, false)
    if (file == null) return file
    return HxdWrapFile(this, uri, file)
  }

  private File? resolveRec(Uri uri, Context cx)
  {
    // /rec/{id}
    if (uri.path.size > 2) return null
    return HxdRecFile(cx, uri)
  }

  private File nonexistent(Uri uri)
  {
    SyntheticFile(uri)
  }
}

