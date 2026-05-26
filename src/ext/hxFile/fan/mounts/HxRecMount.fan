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
** Mount folio rec files into the virtual filesystem as 'rec/{id}'
**
const class HxRecMount : HxWrapMount
{
  new make(HxFileExt ext, Dict config) : super(ext, config)
  {
  }

  override File resolve(Uri uri, Str mode := "r")
  {
    if (isRoot(uri)) return nonexistent(uri)
    if (!fileAccess.allowed(uri, mode)) return nonexistent(uri)
    if (uri.path.size != 1) throw ArgErr("Invalid rec uri: ${uri}")

    // resolve the backing file against folio file implementation
    ref := Ref(uri.name)
    return cx.proj.db.file.get(ref, false) ?: nonexistent(uri)
  }

  override File[] list(Uri uri)
  {
    acc := File[,]

    // Only the root can currently be listed. But eventually we may impose
    // a hierarchical view of the recs
    if (!isRoot(uri)) return acc

    cx.proj.readAll("sys::File").each |rec|
    {
      id     := rec.id.toProjRel
      recUri := `${id}`
      // if (!isFileAccessible(cx, recUri, "r")) return
      f := ext.resolve(mountAbs(recUri))
      if (f.exists) acc.add(f)
    }

    return acc
  }
}