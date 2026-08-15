//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Aug 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** RepoServerEnv is an environment whose libs come from a RepoServer rather
** than the local file system.  A registry uses it to compile an uploaded
** lib against dependencies from its own catalog instead of whatever
** happens to be installed for the local runtime.
**
** Dependency solving uses catalog metadata only; a lib's xetolib zip is
** fetched lazily the first time its file is needed and cached on the
** local disk.  Published versions are immutable so cache entries are
** shared across instances and never invalidated.
**
** Each instance owns its own compiled lib cache, so building a namespace
** here never touches the process wide environment.
**
const class RepoServerEnv : LocalEnv
{
  ** Construct for the given server and local cache directory
  new make(RepoServer server, File cacheDir)
  {
    if (!cacheDir.isDir) throw ArgErr("Not a dir: $cacheDir")
    this.server   = server
    this.cacheDir = cacheDir.normalize
  }

  ** Server used to list versions and fetch xetolib zips
  const RepoServer server

  ** Local directory where fetched xetolib zips are cached
  const File cacheDir

  override once LocalRepo repo() { RepoServerRepo(this) }

  override Str mode() { "repo" }

  override File[] path() { File#.emptyList }

  override File homeDir() { cacheDir }

  override File workDir() { cacheDir }

  override File installDir() { cacheDir }

  override Str:Str debugProps()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["xeto.version"]  = typeof.pod.version.toStr
    acc["xeto.mode"]     = mode
    acc["xeto.cacheDir"] = cacheDir.osPath
    acc["xeto.server"]   = server.typeof.qname
    return acc
  }

}

**************************************************************************
** RepoServerRepo
**************************************************************************

**
** LocalRepo implementation backed by a RepoServer.  Version lookup and
** dependency solving use only catalog metadata; zip bytes are fetched
** on demand by `RepoLibVersion.file`.
**
internal const class RepoServerRepo : MLocalRepo
{
  new make(RepoServerEnv env) : super(env) { this.repoEnv = env }

  const RepoServerEnv repoEnv

  RepoServer server() { repoEnv.server }

  override LibVersion[] libs()
  {
    throw UnsupportedErr("RepoServer does not enumerate all libs")
  }

  override LibVersion? lib(Str name, Bool checked := true)
  {
    v := best(name, null)
    if (v != null) return v
    if (checked) throw UnknownLibErr(name)
    return null
  }

  override LibVersion? depend(LibDepend d, Bool checked := true)
  {
    v := best(d.name, d.versions)
    if (v != null) return v
    if (checked) throw UnknownLibErr(d.toStr)
    return null
  }

  override LibVersion[] resolveDepends(LibDepend[] libs)
  {
    DependSolver(this, libs).solve
  }

  override This rescan() { this }

  ** Query the server and map the best matching version.  The constraint
  ** is passed to the server but also verified here since the server is
  ** free to ignore it.
  private RepoLibVersion? best(Str name, LibDependVersions? constraint)
  {
    dicts := server.versions(name, constraint, null)
    RepoLibVersion? best := null
    dicts.each |dict|
    {
      v := RepoLibVersion(this, dict)
      if (constraint != null && !constraint.contains(v.version)) return
      if (best == null || v.version > best.version) best = v
    }
    return best
  }

//////////////////////////////////////////////////////////////////////////
// Fetch
//////////////////////////////////////////////////////////////////////////

  ** Fetch the xetolib zip for the given version into the cache and
  ** return the cached file.  Cache entries are immutable and shared;
  ** concurrent fetches of the same version race benignly since both
  ** produce identical bytes.
  File fetch(RepoLibVersion v)
  {
    file := repoEnv.cacheDir + `${v.name}-${v.version}.xetolib`
    if (file.exists) return file

    // stream server file into a temp sibling
    temp := file.parent + `${file.name}.tmp-${Buf.random(4).toHex}`
    out := temp.out
    try
    {
      server.fetch(v.name, v.version).in.pipe(out)
      out.close
    }
    catch (Err e)
    {
      out.close
      temp.delete
      throw e
    }

    // verify against the catalog digest when we have one; a mismatch
    // means corruption or tampering between catalog and storage
    if (v.digest != null)
    {
      actual := XetoZipUtil.digestStream(temp.in)
      if (actual != v.digest)
      {
        temp.delete
        throw Err("Digest mismatch fetching $v: catalog $v.digest, fetched $actual")
      }
    }

    // atomic move; if a concurrent fetch won the race keep its copy
    try
    {
      temp.moveTo(file)
    }
    catch (Err e)
    {
      temp.delete
      if (!file.exists) throw e
    }
    return file
  }
}

**************************************************************************
** RepoLibVersion
**************************************************************************

**
** LibVersion built from RepoServer catalog metadata.  Extends the
** metadata-only RemoteLibVersion with a file which is fetched into the
** local cache on first use, so versions which are solved but never
** compiled cost no fetch.
**
internal const class RepoLibVersion : RemoteLibVersion
{
  new make(RepoServerRepo repo, Dict dict) : super.makeDict(dict)
  {
    this.repo = repo
  }

  const RepoServerRepo repo

  override File? file(Bool checked := true)
  {
    f := fileRef
    if (f == null)
    {
      // lazy fetch using the same setConst idiom as FileLibVersion.digest;
      // a concurrent race is benign since both resolve the same cache file
      f = repo.fetch(this)
      #fileRef->setConst(this, f)
    }
    return f
  }
  private const File? fileRef

  override Void eachSrcFile(|File| cb)
  {
    zip := Zip.open(file)
    try
      zip.contents.each |f| { if (f.ext == "xeto") cb(f) }
    finally
      zip.close
  }

}
