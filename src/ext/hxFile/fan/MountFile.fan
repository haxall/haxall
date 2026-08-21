//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2026  Matthew Giannini Creation
//

using concurrent
using util
using xeto
using haystack
using hx

**
** A file in the virtual filesystem.
**
const class MountFile : SyntheticFile
{
  new make(FileExt fileExt, Uri uri, User? user := null) : super(uri)
  {
    this.fileExt = fileExt
    this.user    = user
  }

  ** The file ext which resolved this file
  const FileExt fileExt

  ** User which resolved this file, used to bind a context when this
  ** file is used from a thread which does not have one
  const User? user

  virtual Mount root() { fileExt.root }

  **
  ** Run f with a context bound to the current thread.  Files are typically
  ** resolved on a thread with a context, but may be used later from a thread
  ** without one (background actors, cached file handles).  In that case we
  ** create a context for the user which resolved the file so that mount
  ** resolution and access checks still run against the correct user.
  **
  private Obj? withCx(|->Obj?| f)
  {
    if (Context.cur(false) != null) return f()
    if (user == null) throw ContextUnavailableErr("No context and no user bound: $uri")
    return fileExt.rt.newContext(user).asCur |->Obj?| { f() }
  }

  override Bool exists() { withCx |->Obj?| { root.exists(uri) } }

  override Int? size() { withCx |->Obj?| { root.size(uri) } }

  override Bool isEmpty() { withCx |->Obj?| { root.isEmpty(uri) } }

  override DateTime? modified
  {
    get { withCx |->Obj?| { root.modified(uri) } }
    set { throw UnsupportedErr() }
  }

  internal Str:Obj? attrs() { withCx |->Obj?| { root.attrs(uri) } }

  override Bool isHidden() { attrs["hidden"] }

  override Bool isReadable() { attrs["readable"] }

  override Bool isWritable() { attrs["writable"] }

  override Bool isExecutable() { attrs["executable"] }

  override Str? osPath() { null }

  override File? parent()
  {
    parentUri := uri.parent
    if (parentUri == null) return null
    return withCx |->Obj?| { root.ext.resolve(parentUri) }
  }

  override File[] list(Regex? pattern := null)
  {
    File[] files := withCx |->Obj?| { root.list(uri).map { HxListFile.wrap(it) } }
    if (pattern == null) return files
    return files.findAll |f| { pattern.matches(f.name) }
  }

  override File normalize() { return this }

  @Operator override File plus(Uri path, Bool checkSlash := true)
  {
    withCx |->Obj?| { root.ext.resolve(uri.plus(path)) }
  }

  virtual File toLocal() { withCx |->Obj?| { root.toLocal(uri) } ?: throw IOErr("Not a local file ${uri}") }

  override File create()
  {
    try return withCx |->Obj?| { root.create(uri) }
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

    return withCx |->Obj?| { root.moveTo(uri, to) }
  }

  override Void delete()
  {
    if (!exists) return
    try withCx |->Obj?| { root.delete(uri); return null }
    catch (IOErr err) throw err
    catch (Err err) throw IOErr("Delete failed", err)
  }

  override InStream in(Int? bufferSize := 4096)
  {
    if (isDir) throw IOErr("Cannot open InStream for directory: $uri")
    return withCx |->Obj?|
    {
      if (!root.exists(uri)) throw IOErr("File does not exist: $uri")
      return root.in(uri, bufferSize)
    }
  }

  override Obj? withIn(|InStream->Obj?| f)
  {
    withCx |->Obj?| { root.withIn(uri, null, f) }
  }

  override OutStream out(Bool append := false, Int? bufferSize := 4096)
  {
    try
    {
      if (isDir) throw IOErr("Cannot write a directory: $uri")
      return withCx |->Obj?| { root.out(uri, append, bufferSize) }
    }
    catch (IOErr err) throw err
    catch (Err err) throw IOErr("Failed to opend $uri for write", err)
  }

  override Void withOut(|OutStream| f)
  {
    withCx |->Obj?| { root.withOut(uri, null, f); return null }
  }
}

**************************************************************************
** HxListFile
**************************************************************************

**
** Only used to wrap MountFile.list() files. The file attrs are resolved on
** first access and then cached so we don't have to do a full security-checked
** resolution to get these values.  Note this means each entry of a list()
** snapshots its attrs when it is first read, not when the list was made.
** Should only be used as a result of MountFile.list() and should generally
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
  }

  private const MountFile f
  private const AtomicRef attrsRef := AtomicRef(null)

  ** Attrs are resolved lazily on first access and then cached.  Computing
  ** them costs a security checked resolution plus a file attribute syscall
  ** per attribute, so we must not pay that for every entry of a list()
  private Str:Obj attrs()
  {
    a := attrsRef.val
    if (a == null) attrsRef.val = a = f.attrs.toImmutable
    return a
  }

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
