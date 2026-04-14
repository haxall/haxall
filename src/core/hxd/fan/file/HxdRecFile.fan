//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Aug 2026  Brian Frank  Port
//

using concurrent
using xeto
using haystack
using folio
using hx
using hxm
using hxFolio
using util

**
** Models a file mounted in the /rec/ virtual file system
**
internal const class HxdRecFile : SyntheticFile
{
  new makeNew(Context cx, Uri uri) : super.make(uri)
  {
    this.cxRef = Unsafe(cx)
  }

  private Context cx() { cxRef.val }
  private const Unsafe cxRef
  private HxdFileExt fileExt() { cx.sys.file }

  override Bool exists()
  {
    if (isRoot) return true
    return recFile?.exists ?: false
  }

  override Int? size()
  {
    if (isRoot) return null
    return recFile?.size
  }

  override DateTime? modified
  {
    get
    {
      if (isRoot) return null
      return recFile?.modified
    }
    set { }
  }

  override File? parent()
  {
    parentUri := uri.parent
    if (parentUri == null) return null
    return fileExt.doResolve(uri, cx)
  }

  override File[] list(Regex? pattern := null)
  {
    acc := File[,]

    if (!isRoot) return acc

    cx.db.readAll(Filter("sys::File")).each |rec|
    {
      id := rec.id.toProjRel
      f := fileExt.doResolve(`/rec/${id}`, cx)
      if (pattern == null || pattern.matches(f.name)) acc.add(f)
    }

    return acc
  }

  override File create() { this }

  override Void delete()
  {
    if (isRoot) throw IOErr("${uri}")
    recFile?.delete
  }

  @Operator override File plus(Uri path, Bool checkSlash := true)
  {
    throw UnsupportedErr()
  }

  override Obj? withIn(|InStream->Obj?| f)
  {
    if (isRoot) throw IOErr("${uri}")
    return recFile.withIn(f)
  }

  override Void withOut(|OutStream| f)
  {
    if (isRoot) throw IOErr("${uri}")
    recFile.withOut(f)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Bool isRoot() { uri == `/rec/` }
  private Ref id() { Ref(uri.path[1]) }
  private File? recFile() { cx.db.file.get(id, false) }
}

