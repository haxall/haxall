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
** Exposes Xeto libraries and their files as: `{xetoLib}/{path}`
**
** The Xeto LibFiles API only lists resource files (not directories), even
** though they may be stored in directories in the lib itself.  A file uri
** resolves to its LibFile via `toLibFile`; directories are derived from
** the file paths.
**
const class LibMount : Mount
{
  new make(FileExt ext, Dict config) : super(ext, config)
  {
  }

  private Namespace ns() { cx.ns }

//////////////////////////////////////////////////////////////////////////
// Mount
//////////////////////////////////////////////////////////////////////////

  override Bool exists(Uri uri)
  {
    if (isRoot(uri)) return true
    if (uri.isDir) return dirExists(uri)
    return toLibFile(uri) != null
  }

  override Int? size(Uri uri)
  {
    toLibFile(uri)?.size
  }

  override Str:Obj? attrs(Uri uri)
  {
    acc := super.attrs(uri)
    f := toLibFile(uri)
    if (f != null) acc.addNotNull("modified", f.modified)
    return acc
  }

  override Bool isEmpty(Uri uri)
  {
    uri.isDir ? list(uri).isEmpty : toLibFile(uri) == null
  }

  override DateTime? modified(Uri uri)
  {
    toLibFile(uri)?.modified
  }

  override File[] list(Uri uri)
  {
    // list all libs
    if (isRoot(uri)) return ns.libs.map { ext.resolve(mountAbs(`${it.name}/`)) }

    lib := toLib(uri)
    if (lib == null) return File[,]

    // collapse the accessible files into their immediate child entries;
    // a directory only shows up when an accessible file lives under it
    path := toPath(uri)
    children := Uri:File[:] { ordered = true }
    accessible(lib).each |f|
    {
      fileUri := f.uri
      if (fileUri == path || !fileUri.toStr.startsWith(path.toStr)) return
      child := `${path}${fileUri.relTo(path)[0..<1]}`
      children[child] = ext.resolve(mountAbs(`${lib.name}${child}`))
    }
    return children.vals
  }

  // override InStream in(Uri uri, Int? bufferSize)
  // {
  //   toLibFile(uri)?.in(bufferSize) ?: throw IOErr("${uri}")
  // }

  override Obj? withIn(Uri uri, [Str:Obj]? opts, |InStream->Obj?| f)
  {
    toLibFile(uri)?.read(f) ?: throw IOErr("${uri}")
  }

//////////////////////////////////////////////////////////////////////////
// Resolution
//////////////////////////////////////////////////////////////////////////

  ** Resolve a mount uri to its LibFile or null.  Only published files
  ** are reachable: a file which is merely packaged in the lib does not
  ** resolve even by its exact path.  Directories never map to a LibFile.
  LibFile? toLibFile(Uri uri)
  {
    if (isRoot(uri) || uri.isDir) return null

    lib := toLib(uri)
    if (lib == null) return null

    f := lib.files.get(toPath(uri), false)
    if (f == null || !f.isPublished || !canAccess(f)) return null
    return f
  }

  ** A directory exists if it is a lib root or an accessible file lives under it
  private Bool dirExists(Uri uri)
  {
    lib := toLib(uri)
    if (lib == null) return false

    path := toPath(uri)
    if (path == `/`) return true
    return accessible(lib).any |f| { f.uri.toStr.startsWith(path.toStr) }
  }

  ** The published files readable thru this mount
  private LibFile[] accessible(Lib lib)
  {
    lib.files.published.findAll |f| { canAccess(f) }
  }

  ** A published file is officially part of the lib's public API, so the
  ** publish list is its own whitelist; anything else falls back to the
  ** file extension whitelist
  private Bool canAccess(LibFile f)
  {
    f.isPublished || fileAccess.whitelisted(f.uri)
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Lib? toLib(Uri uri)
  {
    if (uri.path.size == 1 && !uri.isDir) return null

    libName := uri.path.getSafe(0)
    if (libName == null) return null

    return ns.lib(libName, false)
  }

  ** {xetoLib}/{path} => {path}
  private Uri toPath(Uri uri)
  {
    if (uri.path.size < 2) return `/`
    return uri.getRangeToPathAbs(1..-1)
  }
}
