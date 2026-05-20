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
** Dynamic mounts support mounting/unmounting submounts
**
const abstract class HxDynamicMount : HxMount
{
  new make(IFileExt ext, Dict config) : super(ext, config)
  {
  }

//////////////////////////////////////////////////////////////////////////
// DynamicMount
//////////////////////////////////////////////////////////////////////////

  // TODO: mount/unmount

  ** Get the submount that should handle this uri
  abstract HxMount? resolveSubmount(Uri uri)

  ** Get a new uri that is relative to its submount
  virtual Uri submountRelUri(Uri uri) { uri.relTo(resolveSubmount(uri).mountPoint) }

  ** List all direct mounts (non-recursive)
  abstract HxMount[] mounts()

//////////////////////////////////////////////////////////////////////////
// Mount
//////////////////////////////////////////////////////////////////////////

  override Bool exists(Uri uri)
  {
    return resolveSubmount(uri)?.exists(submountRelUri(uri)) ?: false
  }

  override Int? size(Uri uri)
  {
    resolveSubmount(uri)?.size(submountRelUri(uri))
  }

  override Bool isEmpty(Uri uri)
  {
    resolveSubmount(uri)?.isEmpty(submountRelUri(uri)) ?: true
  }

  override DateTime? modified(Uri uri)
  {
    resolveSubmount(uri)?.modified(submountRelUri(uri))
  }

  override Str:Obj attrs(Uri uri)
  {
    resolveSubmount(uri)?.attrs(submountRelUri(uri)) ?: super.attrs(uri)
  }

  override File? toLocal(Uri uri)
  {
    resolveSubmount(uri)?.toLocal(submountRelUri(uri))
  }

  override File create(Uri uri)
  {
    resolveSubmount(uri)?.create(submountRelUri(uri)) ?: super.create(uri)
  }

  override protected Void onDelete(Uri uri)
  {
    resolveSubmount(uri)?.delete(submountRelUri(uri))
  }

  override InStream in(Uri uri, Int? bufferSize)
  {
    resolveSubmount(uri)?.in(submountRelUri(uri), bufferSize) ?: super.in(uri, bufferSize)
  }

  override Obj? withIn(Uri uri, [Str:Obj]? opts, |InStream->Obj?| f)
  {
    resolveSubmount(uri)?.withIn(submountRelUri(uri), opts, f) ?: super.withIn(uri, opts, f)
  }

  override OutStream out(Uri uri, Bool append, Int? bufferSize)
  {
    resolveSubmount(uri)?.out(submountRelUri(uri), append, bufferSize) ?: super.out(uri, append, bufferSize)
  }

  override Void withOut(Uri uri, [Str:Obj]? opts, |OutStream| f)
  {
    submount := resolveSubmount(uri)
    if (submount != null) submount.withOut(submountRelUri(uri), opts, f)
    else super.withOut(uri, opts, f)
  }
}
