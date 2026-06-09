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
** Makes pod files and their resources available as: '{podName}/{path}'
**
const class PodMount : WrapMount
{
  new make(FileExt ext, Dict config) : super(ext, config)
  {
  }

  override File resolve(Uri uri, Str mode := "r")
  {
    podUri := toPodUri(uri)
    if (podUri == null) return nonexistent(uri)
    if (podUri.isDir) return HxMountSyntheticDir(uri, this)
    return podUri.toFile
  }

  override Str:Obj? attrs(Uri uri)
  {
    f := resolve(uri)
    return [
      "modified":   f.modified,
      "size":       f.size,
      "hidden":     f.isHidden,
      "readable":   f.isReadable,
      "writable":   f.isWritable,
      "executable": f.isExecutable,
    ]
  }
  override File[] list(Uri uri)
  {
    // list all pods
    if (isRoot(uri)) return Pod.list.map { ext.resolve(mountAbs(`$it.name/`)) }

    acc := File[,]

    // list a directory in a pod
    pod := toPod(uri)
    if (pod == null) return acc

    path := toPath(uri)

    children := [Uri:File][:]
    pod.files.each |file|
    {
      fileUri := file.uri.pathOnly
      if (fileUri != path && fileUri.toStr.startsWith(path.toStr))
      {
        rel := fileUri.relTo(path)
        children[rel[0..<1]] = file
      }
    }
    children.each |file, rel|
    {
      podPath := `${path}${rel}`
      // check access
      if (!canAccess(podPath)) return
      // don't show empty directories
      if (podPath.isDir && isPodDirEmpty(pod, podPath)) return
      acc.add(ext.resolve(mountAbs(`${pod.name}${podPath}`)))
    }
    return acc
  }

  private Bool isPodDirEmpty(Pod pod, Uri dir)
  {
    access := this.fileAccess
    child := pod.files.eachWhile |file| {
      fileUri := file.uri.pathOnly
      if (fileUri == dir || fileUri.isDir) return null
      if (!fileUri.toStr.startsWith(dir.toStr)) return null
      if (!canAccess(fileUri, access)) return null
      return file
    }
    return child == null
  }

  override Obj? withIn(Uri uri, [Str:Obj]? opts, |InStream->Obj?| f)
  {
    try
    {
      file := toPodUri(uri)?.toFile
      if (file == null) throw IOErr("Cannot read: ${uri}")
      return file.withIn(f)
    }
    catch (UnresolvedErr err)
      throw IOErr("Cannot read: ${uri}")
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Uri? toPodUri(Uri uri)
  {
    if (isRoot(uri)) return `fan:///`

    pod := toPod(uri)
    if (pod == null) return null

    path := toPath(uri)
    if (path == `/` && !uri.isDir) return null

    // check access
    if (!canAccess(path)) return null

    if (path.isDir)
    {
      return pod.files.eachWhile |file|
      {
        fileUri := file.uri.pathOnly
        dir := fileUri.isDir ? fileUri : fileUri.parent
        return dir == path ? `fan://${pod.name}${path}` : null
      }
    }

    podFile := pod.file(path, false)
    if (podFile == null) return null

    return podFile.uri
  }

  private static Pod? toPod(Uri uri)
  {
    podName := uri.path.getSafe(0)
    if (podName == null) return null

    return Pod.find(podName, false)
  }

  ** {pod}/{path} => /{path}
  private static Uri toPath(Uri uri)
  {
    if (uri.path.size < 2) return `/`
    return uri.getRangeToPathAbs(1..-1)
  }

  ** Should only be used on paths
  private Bool canAccess(Uri path, FileAccess access := this.fileAccess)
  {
    // cannot access /lib/ files
    if (path.toStr.startsWith("/lib/")) return false

    // other dirs are ok
    if (path.isDir) return true

    // check whitelist for a file
    if (!access.whitelisted(path)) return false

    return true
  }
}