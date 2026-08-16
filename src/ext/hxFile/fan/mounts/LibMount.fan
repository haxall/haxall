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
** though they may be stored in directories in the lib itself. So we have
** to do some work to figure out the actual filesystem layout of the lib.
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
    toLibUri(uri) != null
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

    acc := File[,]

    // list a directory
    lib := toLib(uri)
    if (lib == null) return acc

    path := toPath(uri)

    children := [Uri:LibFile][:]
    lib.files.list.each |f|
    {
      fileUri := f.uri
      if (fileUri != path && fileUri.toStr.startsWith(path.toStr))
      {
        rel := fileUri.relTo(path)
        children[rel[0..<1]] = f
      }
    }
    children.each |file, rel|
    {
      libPath := `${path}${rel}`
      // check access
      if (!canAccess(libPath)) return
      // don't show empty directories
      if (libPath.isDir && isLibDirEmpty(lib, libPath)) return
      acc.add(ext.resolve(mountAbs(`${lib.name}${libPath}`)))
    }
    return acc
  }

  private Bool isLibDirEmpty(Lib lib, Uri dir)
  {
    // lib files are always files, never directory entries
    child := lib.files.list.eachWhile |f| {
      fileUri := f.uri
      if (fileUri == dir) return null
      if (!fileUri.toStr.startsWith(dir.toStr)) return null
      if (!canAccess(fileUri)) return null
      return fileUri
    }
    return child == null
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
// Security
//////////////////////////////////////////////////////////////////////////

  private Bool canAccess(Uri path)
  {
    if (path.isDir) return true

    // check whitelist for a file
    if (!fileAccess.whitelisted(path)) return false

    return true
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Uri? toLibUri(Uri uri)
  {
    if (isRoot(uri)) return `xeto:///`

    lib := toLib(uri)
    if (lib == null) return null

    path := toPath(uri)

    // check access
    if (!canAccess(path)) return null

    if (path.isDir)
    {
      // if it is just the lib dir then it always exists
      if (path == `/`) return uri
      return lib.files.list.eachWhile |f|
      {
        f.uri.toStr.startsWith(path.toStr) ? f.uri : null
      }
    }

    libFile := lib.files.get(path, false)
    if (libFile == null) return null

    return libFile.uri
  }

  private Lib? toLib(Uri uri)
  {
    if (uri.path.size == 1 && !uri.isDir) return null

    libName := uri.path.getSafe(0)
    if (libName == null) return null

    return ns.lib(libName, false)
  }

  ** {xetoLib}/{path} => {path}
  Uri toPath(Uri uri)
  {
    if (uri.path.size < 2) return `/`
    return uri.getRangeToPathAbs(1..-1)
  }

  LibFile? toLibFile(Uri uri)
  {
    if (isRoot(uri) || uri.isDir) return null

    lib := toLib(uri)
    if (lib == null) return null

    path := toPath(uri)

    if (!canAccess(path)) return null

    return lib.files.get(path, false)
  }
}

