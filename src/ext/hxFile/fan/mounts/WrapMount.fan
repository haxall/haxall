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
** A mount that delegates all operations to another "backing" file
**
const abstract class WrapMount : Mount
{
  new make(FileExt ext, Dict config) : super(ext, config)
  {
  }

  ** Resolve the relative uri to its backing file
  protected abstract File resolve(Uri uri, Str mode := "r")

  override Bool exists(Uri uri) { isRoot(uri) || resolve(uri).exists }

  override Int? size(Uri uri) { resolve(uri).size }

  override Bool isEmpty(Uri uri) { resolve(uri).isEmpty }

  override DateTime? modified(Uri uri) { resolve(uri).modified }

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
  ** Pre-condition: uri must represent a dir/
  override File[] list(Uri uri) { File[,] }

  override File? toLocal(Uri uri)
  {
    f := resolve(uri)
    if (f.typeof.name == "LocalFile") return f
    return null
  }

  override File create(Uri uri)
  {
    f := resolve(uri, "rw").create
    return ext.resolve(mountAbs(uri))
  }

  override protected Void onDelete(Uri uri)
  {
    resolve(uri, "rw").delete
  }

  override InStream in(Uri uri, Int? bufferSize)
  {
    resolve(uri).in(bufferSize)
  }

  override Obj? withIn(Uri uri, [Str:Obj]? opts, |InStream->Obj?| f)
  {
    resolve(uri).withIn(f)
  }

  override OutStream out(Uri uri, Bool append, Int? bufferSize)
  {
    resolve(uri, "rw").out(append, bufferSize)
  }

  override Void withOut(Uri uri, [Str:Obj]? opts, |OutStream| f)
  {
    resolve(uri, "rw").withOut(f)
  }
}
