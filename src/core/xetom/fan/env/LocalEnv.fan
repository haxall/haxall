//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Aug 2026  Brian Frank  Creation
//

using concurrent
using crypto
using util
using xeto

**
** LocalEnv is the base for environments running in a JVM with file
** system access: FileEnv and RepoServerEnv.  It handles the
** implementations which can never run in a browser.
**
abstract const class LocalEnv : MEnv
{
  ** Add given directory to the front of the Fantom env path and
  ** reinitialize the current environment to pick up the new path.
  ** The directory is included in the xeto path resolution regardless
  ** of mode (even when path is pinned by xeto.props).
  @NoDoc static XetoEnv addToPath(File dir)
  {
    pathEnv := Env.cur as PathEnv ?: throw Err("Env.cur not a PathEnv")
    dir = dir.normalize
    pathEnv.addToPath(dir)
    adds := pathAdds
    if (!adds.contains(dir)) pathAddsRef.val = adds.dup.add(dir).toImmutable
    return reinit
  }

  ** Directories explicitly added to the path via addToPath
  @NoDoc static File[] pathAdds() { pathAddsRef.val ?: File#.emptyList }
  private const static AtomicRef pathAddsRef := AtomicRef()

  override Bool isRemote() { false }

  override once RemoteRepoRegistry remoteRepos()
  {
    MRemoteRepoRegistry(this)
  }

  override Namespace resolveNamespace(Str[] names)
  {
    if (names.isEmpty) names = ["sys"]
    depends := names.map |n->LibDepend| { LibDepend(n) }
    return createNamespace(repo.resolveDepends(depends))
  }

  override Namespace deriveNamespace(Dict[] recs)
  {
    resolveNamespace(XetoUtil.dataToLibs(recs))
  }

  override Namespace createInstalledNamespace()
  {
    createNamespace(repo.libs)
  }

  override Str libCacheKey(MLib lib)
  {
    XetoCrypto.libCacheKey(lib)
  }

  override Int computeInheritanceDigest(Spec t)
  {
    XetoCrypto.computeInheritanceDigest(t)
  }

  private static Void updateInheritanceDigest(Digest d, Spec t)
  {
    d.updateAscii(t.qname)
    if (t.base == null) return
    updateInheritanceDigest(d, t.base)
    if (t.isCompound)
    {
      t.ofs.each |of| { updateInheritanceDigest(d, of) }
    }
  }

  override Void dump(OutStream out := Env.cur.out)
  {
    AbstractMain.printProps(debugProps, ["out":out])
  }
}

