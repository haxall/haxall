//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Aug 2026  Brian Frank  Creation
//

using concurrent
using xeto
using xetom
using haystack

**
** RepoServerEnvTest verifies compiling against a RepoServer backed
** environment: solving from catalog metadata alone, lazy fetch into
** the shared cache, and isolation from the process wide env.
**
class RepoServerEnvTest : Test
{
  Void test()
  {
    // registry server over the local namespace
    ns := XetoEnv.cur.resolveNamespace(["ph.points"])
    server := CountingRepoServer(NamespaceRepoServer(ns, "test"))
    cacheDir := (tempDir + `cache/`).create

    // solving uses catalog metadata only - zero fetches
    env := RepoServerEnv(server, cacheDir)
    depends := env.repo.resolveDepends([LibDepend("ph.points")])
    verify(depends.any |v| { v.name == "ph.points" })
    verify(depends.any |v| { v.name == "sys" })
    verifyEq(server.fetches.val, 0)

    // building the namespace fetches the closure into the cache
    rns := env.createNamespace(depends)
    lib := rns.lib("ph.points")
    verifyEq(lib.name, "ph.points")
    verify(lib.specs.list.size > 0)
    fetched := server.fetches.val
    verifyEq(fetched, depends.size)

    // cache dir contains exactly the closure's zips
    cached := cacheDir.list.findAll |f| { f.ext == "xetolib" }
    verifyEq(cached.size, depends.size)
    depends.each |v|
    {
      verify(cacheDir.plus(`${v.name}-${v.version}.xetolib`).exists, v.toStr)
    }

    // a second env over the same cache compiles without re-fetching,
    // and its compiled lib cache is independent of the first env
    env2 := RepoServerEnv(server, cacheDir)
    depends2 := env2.repo.resolveDepends([LibDepend("ph.points")])
    rns2 := env2.createNamespace(depends2)
    verifyEq(rns2.lib("ph.points").name, "ph.points")
    verifyEq(server.fetches.val, fetched)
    verifyNotSame(rns.lib("sys"), rns2.lib("sys"))

    // process wide env is untouched by everything above
    verifyEq(XetoEnv.cur.mode == "repo", false)

    // unknown lib rejected at solve time
    verifyErr(UnknownLibErr#) { env.repo.lib("acme.no.such.lib") }

    // catalog digest mismatch detected at fetch time
    bad := RepoServerEnv(BadDigestRepoServer(NamespaceRepoServer(ns, "bad")), (tempDir + `bad/`).create)
    badDepends := bad.repo.resolveDepends([LibDepend("sys")])
    verifyErr(Err#) { badDepends.first.file }
  }
}

**************************************************************************
** CountingRepoServer
**************************************************************************

** RepoServer wrapper which counts fetch calls
internal const class CountingRepoServer : RepoServer
{
  new make(RepoServer wrap) { this.wrap = wrap }
  const RepoServer wrap
  const AtomicInt fetches := AtomicInt()

  override Dict ping() { wrap.ping }
  override Dict search(Str query, Int limit) { wrap.search(query, limit) }
  override Dict[] versions(Str lib, LibDependVersions? versions, Int? limit) { wrap.versions(lib, versions, limit) }
  override Dict publish(File file) { wrap.publish(file) }
  override File fetch(Str lib, Version version)
  {
    fetches.incrementAndGet
    return wrap.fetch(lib, version)
  }
}

**************************************************************************
** BadDigestRepoServer
**************************************************************************

** RepoServer wrapper which lies about the catalog digest
internal const class BadDigestRepoServer : RepoServer
{
  new make(RepoServer wrap) { this.wrap = wrap }
  const RepoServer wrap

  override Dict ping() { wrap.ping }
  override Dict search(Str query, Int limit) { wrap.search(query, limit) }
  override Dict[] versions(Str lib, LibDependVersions? versions, Int? limit)
  {
    wrap.versions(lib, versions, limit).map |d->Dict| { Etc.dictSet(d, "digest", "sha256:bogus") }
  }
  override File fetch(Str lib, Version version) { wrap.fetch(lib, version) }
  override Dict publish(File file) { wrap.publish(file) }
}
