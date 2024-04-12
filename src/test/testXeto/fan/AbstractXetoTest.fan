//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xeto::Dict
using xeto::Lib
using haystack
using haystack::Ref
using xetoEnv

**
** AbstractXetoTest
**
@Js
class AbstractXetoTest : HaystackTest
{

  Obj none() { Remove.val }

  Obj na() { NA.val }

  Ref ref(Str id, Str? dis := null) { Ref(id, dis) }

  Dict dict0() { Etc.dict0 }

  Dict dict1(Str n0, Obj v0) { Etc.dict1(n0, v0) }

  Dict dict2(Str n0, Obj v0, Str n1, Obj v1) { Etc.dict2(n0, v0, n1, v1) }

  Dict dict(Str:Obj map) { Etc.dictFromMap(map) }

  static Dict nameDictEmpty() { MNameDict.empty }

  Void verifyLocalAndRemote(Str[] libs, |LibNamespace ns| f)
  {
    // first test local server
    server := TestServer(createNamespace(libs))
    verifyEq(server.ns.isRemote, false)
    f(server.ns)

    // setup remote client
    client := TestClient(server)
    client.boot
    verifyEq(client.ns.isRemote, true)
    client.ns.libsAsync |e, x|
    {
      if (e != null) throw e
      verifyEq(x.size, server.ns.versions.size)
      f(client.ns)
    }
  }

  LibNamespace sysNamespace()
  {
    LibRepo.cur.bootNamespace
  }

  LibNamespace createNamespace(Str[] libs)
  {
    if (libs.size == 1 && libs[0] == "sys")
      return sysNamespace

    repo    := LibRepo.cur
    depends := libs.map |n->LibDepend| { LibDepend(n) }
    vers    := repo.solveDepends(depends)
    return repo.createNamespace(vers)
  }

  Obj? compileData(Str s, Dict? opts := null)
  {
    LibRepo.cur.bootNamespace.compileData(s, opts)
  }

  Dict[] compileDicts(Str s, Dict? opts := null)
  {
    LibRepo.cur.bootNamespace.compileDicts(s, opts)
  }

  Void verifyFitsExplain(LibNamespace ns, Obj? val, Spec spec, Str[] expected)
  {
    cx := TextContext()
    hits := XetoLogRec[,]
    explain := |XetoLogRec rec| { hits.add(rec) }
    opts := Etc.dict1("explain", Unsafe(explain))
    ns.fits(cx, val, spec, opts)
    if (expected.size != hits.size)
    {
      echo("FAIL verifyFitsExplain $val $spec [$hits.size != $expected.size]")
      echo(hits.join("\n"))
      fail
    }
    expected.each |expect, i|
    {
      verifyEq(expect, hits[i].msg)
    }
  }
}

**************************************************************************
** TextContext
**************************************************************************

@Js
class TextContext : XetoContext
{
  override Dict? xetoReadById(Obj id) { null }
  override Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f) { null }
  override Bool xetoIsSpec(Str spec, Dict rec) { false }
}

**************************************************************************
** TestServer
**************************************************************************

@Js
const class TestServer
{
  new make(LibNamespace ns)
  {
    this.ns = ns
    this.io = XetoBinaryIO.makeServer(ns)
  }

  const LibNamespace ns
  const XetoBinaryIO io
}

**************************************************************************
** TestClient
**************************************************************************

@Js
const class TestClient : RemoteLibLoader
{
  new make(TestServer server) { this.server = server }

  const TestServer server

  RemoteNamespace? ns() { nsRef.val }
  const AtomicRef nsRef := AtomicRef()

  XetoBinaryIO io() { ns.io }

  const Bool debug := false

  This boot()
  {
    buf := Buf()
    server.io.writer(buf.out).writeBoot(server.ns)
    if (debug) echo("   ~~~ init remote bootstrap size = $buf.size bytes ~~~")

    ns := RemoteNamespace.boot(buf.flip.in, this)
    nsRef.val = ns
    return this
  }

  override Void loadLib(Str name, |Err?, Obj?| f)
  {
    serverLib := server.ns.lib(name, false)
    if (serverLib == null) { f(UnknownLibErr(name), null); return }

    buf := Buf()
    server.io.writer(buf.out).writeLib(serverLib)
    if (debug) echo("   ~~~ load lib $name size = $buf.size bytes ~~~")

    clientLib := io.reader(buf.flip.in).readLib(ns)
    f(null, clientLib)
  }
}

