//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2026  Matthew Giannini Creation
//

using util
using xeto
using haystack
using hx

**
** A file in the virtual filesystem.
**
const class MountFile : SyntheticFile
{
  new make(Uri uri) : super(uri)
  {
  }

  virtual FileExt fileExt() { Context.cur.sys.file }
  virtual Mount root() { fileExt.root }

  override Bool exists() { root.exists(uri) }

  override Int? size() { root.size(uri) }

  override Bool isEmpty() { root.isEmpty(uri) }

  override DateTime? modified
  {
    get { root.modified(uri) }
    set { throw UnsupportedErr() }
  }

  internal Str:Obj? attrs() { root.attrs(uri) }

  override Bool isHidden() { attrs["hidden"] }

  override Bool isReadable() { attrs["readable"] }

  override Bool isWritable() { attrs["writable"] }

  override Bool isExecutable() { attrs["executable"] }

  override Str? osPath() { null }

  override File? parent()
  {
    parentUri := uri.parent
    if (parentUri == null) return null
    return root.ext.resolve(parentUri)
  }

  override File[] list(Regex? pattern := null)
  {
    File[] files := root.list(uri).map { HxListFile.wrap(it) }
    if (pattern == null) return files
    return files.findAll |f| { pattern.matches(f.name) }
  }

  override File normalize() { return this }

  @Operator override File plus(Uri path, Bool checkSlash := true)
  {
    root.ext.resolve(uri.plus(path))
  }

  virtual File toLocal() { root.toLocal(uri) ?: throw IOErr("Not a local file ${uri}") }

  override File create()
  {
    try return root.create(uri)
    catch (IOErr err) throw err
    catch (Err err) throw IOErr("Create failed", err)
  }

  **
  ** Move this file to the specified location.  If this file is
  ** a directory, then the entire directory is moved.  If the
  ** target file already exists or the move fails, then an IOErr
  ** is thrown.  Return the `to` destination file.
  **
  override File moveTo(File to)
  {
    if (isDir != to.isDir)
    {
      if (isDir) throw IOErr("to must a dir ${to.uri.toCode}")
      else throw IOErr("to must not be a dir ${to.uri.toCode}")
    }

    if (!this.exists) throw IOErr("source file does not exist: $uri")
    if (to.exists) throw IOErr("to already exists: $to")

    // to maintain security, we do not move files to non-mount files
    if (to isnot MountFile) throw IOErr("Cannot move to file of type $to.typeof: $to")

    return root.moveTo(uri, to)
  }

  override Void delete()
  {
    if (!exists) return
    try root.delete(uri)
    catch (IOErr err) throw err
    catch (Err err) throw IOErr("Delete failed", err)
  }

  override InStream in(Int? bufferSize := 4096)
  {
    if (!exists) throw IOErr("File does not exist: $uri")
    if (isDir) throw IOErr("Cannot open InStream for directory: $uri")
    return root.in(uri, bufferSize)
  }

  override Obj? withIn(|InStream->Obj?| f)
  {
    root.withIn(uri, null, f)
  }

  override OutStream out(Bool append := false, Int? bufferSize := 4096)
  {
    try
    {
      if (isDir) throw IOErr("Cannot write a directory: $uri")
      return root.out(uri, append, bufferSize)
    }
    catch (IOErr err) throw err
    catch (Err err) throw IOErr("Failed to opend $uri for write", err)
  }

  override Void withOut(|OutStream| f)
  {
    root.withOut(uri, null, f)
  }
}

**************************************************************************
** HxListFile
**************************************************************************

**
** Only used to wrap HxMountFile.list() files. It caches the file attrs so we
** don't have to do a full security-checked resolution to get these values.
** Should only be used as a result of HxMountFile.list() and should generally
** only be used in cases where the file is not being cached/store; only for
** obtaining file attributes.
**
internal const class HxListFile : SyntheticFile
{
  static File wrap(File f)
  {
    f is MountFile ? HxListFile(f) : f
  }

  private new make(MountFile f) : super(f.uri)
  {
    this.f = f
    this.attrs = f.attrs
  }

  private const MountFile f
  private const Str:Obj attrs

  override DateTime? modified { get { attrs["modified"] } set { } }
  override Int? size() { attrs["size"] }
  override Bool isHidden() { attrs["hidden"] == true }
  override Bool isReadable() { attrs["readable"] == true }
  override Bool isWritable() { attrs["writable"] == true }
  override Bool isExecutable() { attrs["executable"] == true }

  override File[] list(Regex? pattern := null) { f.list(pattern) }
  override File plus(Uri path, Bool checkSlash := true) { f.plus(path, checkSlash) }
  override Void delete() { f.delete }
  override InStream in(Int? bufferSize := 4096) { f.in(bufferSize) }
  override OutStream out(Bool append := false, Int? bufferSize := 4096) { f.out(append, bufferSize) }
  override Obj? withIn(|InStream->Obj?| f) { this.f.withIn(f) }
  override Void withOut(|OutStream| f) { this.f.withOut(f) }
}


**************************************************************************
** HxMountSyntheticDir
**************************************************************************

**
** Utility class for mounts that have synthetic directory structure
** but real Files backing them (e.g. pods)
**
@NoDoc const class HxMountSyntheticDir : SyntheticFile
{
  new make(Uri uri, Mount mount) : super(uri)
  {
    this.mount = mount
  }

  private const Mount mount

  private FileExt fileExt() { mount.ext }

  override Bool exists() { true }

  override File? parent()
  {
    parentUri := uri.parent
    if (parentUri == null) return null
    return fileExt.resolve(parentUri)
  }

  override File[] list(Regex? pattern := null)
  {
    files := mount.list(uri)
    if (pattern == null) return files
    return files.findAll |f| { pattern.matches(f.name) }
  }
}
