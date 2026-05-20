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
** A mount point in the virtual filesystem
**
const abstract class HxMount
{
  new make(HxFileExt ext, Dict config)
  {
    this.ext = ext
    this.config = config
  }

  ** The file ext
  const HxFileExt ext

  ** Mount config
  const Dict config

  protected virtual Context cx() { Context.cur }
  protected Runtime rt() { ext.rt }

  ** The full, absolute path of this mount in the virtual filesystem
  Uri mountPoint() { config["mountPoint"] ?: config["mountPath"] }

  ** The name of this mount
  Str name() { mountPoint.name }

  ** Get the absolute path through the virtual filesystem to the mount-relative uri
  Uri mountAbs(Uri mountRel)
  {
    if (mountRel.isAbs || mountRel.isPathAbs) throw ArgErr("Not relative: ${mountRel}")
    return mountPoint.plus(mountRel)
  }

//////////////////////////////////////////////////////////////////////////////////
// File - all these methods have the same semantics as similarly
// named methods on sys::File except that they take a Uri (usually mount-relative
// except for the root). This allows for security checks and submount routing.
//////////////////////////////////////////////////////////////////////////////////

  protected static Bool isRoot(Uri uri) { uri.path.isEmpty || uri == `/` }

  virtual Bool exists(Uri uri) { false }

  virtual Int? size(Uri uri) { null }

  virtual Bool isEmpty(Uri uri) { throw ioErr("Unsupported", uri) }

  virtual DateTime? modified(Uri uri) { null }

  virtual Str:Obj attrs(Uri uri)
  {
    ["hidden": false,
     "readable": true,
     "writable": false,
     "executable": false,]
  }

  virtual File[] list(Uri uri) { File[,] }

  virtual File? toLocal(Uri uri) { null }

  virtual File create(Uri uri) { throw ioErr("Read-only", uri) }

  virtual Void delete(Uri uri)
  {
    try
    {
      if (isRoot(uri)) throw ioErr("Cannot delete root of mount", uri)
      onDelete(uri)
    }
    catch (IOErr err) throw err
    catch (Err err) throw ioErr("Delete failed", uri, err)
  }

  protected virtual Void onDelete(Uri uri) { throw UnsupportedErr() }

  virtual InStream in(Uri uri, Int? bufferSize)
  {
    throw ioErr("Read not supported", uri)
  }

  virtual Obj? withIn(Uri uri, [Str:Obj]? opts, |InStream->Obj?| f)
  {
    throw ioErr("Read not supported", uri)
  }

  virtual OutStream out(Uri uri, Bool append, Int? bufferSize)
  {
    throw ioErr("Read-only", uri)
  }

  virtual Void withOut(Uri uri, [Str:Obj]? opts, |OutStream| f)
  {
    throw ioErr("Read-only", uri)
  }

  virtual File moveTo(Uri uri, File to)
  {
    if (to.exists) throw IOErr("'to' already exists: $to")

    // try to make this as efficient as possible

    // 1) determine which submounts ultimately handle this uri
    thisSub := targetMount(mountAbs(uri))
    thatSub := targetMount(to.uri)
    if (thatSub == null) return nonAtomicMoveTo(uri, to)

    // 2) get backing files
    if (thisSub is HxLocalMount && thatSub is HxLocalMount)
    {
      File thisRaw := thisSub->resolve(uri, "rw")
      File thatRaw := thatSub->resolve(to.uri, "rw")
      thisRaw.moveTo(thatRaw)
    }
    else
    {
      nonAtomicMoveTo(uri, to)
    }
    return to
    /*
    thisRaw := backingFile(uri, "rw")
    thatRaw := mod.root.backingFile(to.uri, "rw")
    if (thatRaw == null) return nonAtomicMoveTo(uri ,to)

    // Delegate directly to backing files if
    // 1) they are both local mounts, in which case we use standard "local"
    //    filesystem moveTo
    // 2) or, the two mounts are the same instance, in which case we assume
    //    a backing file moveTo is safe
    isLocal := thisSub is HxLocalMount && thatSub is HxLocalMount
    isSame  := thisSub === thatSub
    if (isLocal || isSame)
    {
      thisRaw.moveTo(thatRaw)
    }
    else
    {
      nonAtomicMoveTo(uri, to)
    }
    return to
    */
  }

  ** Copy the file or directory designated by 'uri' to the specified location.
  ** Then, delete the source file or directory
  protected File nonAtomicMoveTo(Uri uri, File to)
  {
    from := ext.resolve(mountAbs(uri))
    from.copyTo(to, ["overwrite": true])
    from.delete
    return to
  }

//////////////////////////////////////////////////////////////////////////
// Security
//////////////////////////////////////////////////////////////////////////

  HxFileAccess fileAccess() { ext.fileAccess(this) }

  protected Bool precheckAllowed(Uri uri, Str mode) { true }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  protected File nonexistent(Uri uri) { SyntheticFile(uri) }

  protected IOErr ioErr(Str msg, Uri uri, Err? cause := null)
  {
    IOErr("${msg}: ${mountAbs(uri)} [${mountPoint}]", cause)
  }

  protected HxMount? targetMount(Uri uri, HxDynamicMount dyn := ext->root)
  {
    m := dyn.resolveSubmount(uri)
    if (m isnot HxDynamicMount) return m
    return targetMount(dyn.submountRelUri(uri), m)
  }
}