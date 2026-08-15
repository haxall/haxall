//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Aug 2026  Brian Frank  Creation
//

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
  override Bool isRemote() { false }

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

  override Int computeInheritanceDigest(Spec t)
  {
    d := Crypto.cur.digest("SHA-1")
    updateInheritanceDigest(d, t)
    return d.digest.readS8
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

