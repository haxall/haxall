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
using xetoEnv

**
** AbstractXetoTest
**
@Js
class AbstractXetoTest : HaystackTest
{
  Void verifyAllEnvs(Str lib, |XetoEnv| f)
  {
    // first test local
    envRef = XetoEnv.cur
    verifyEq(env.isRemote, false)
    env.lib(lib)
    f(env)

    // test remote
    envRef = initRemote
    verifyEq(env.isRemote, true)

    // make sure sure lib is loaded
    env.libAsync(lib) |e, x|
    {
      if (e != null) throw e
      f(env)
    }
  }

  XetoEnv env()
  {
    if (envRef == null) envRef = XetoEnv.cur
    return envRef
  }

  private XetoEnv? envRef

  Lib compileLib(Str s, Dict? opts := null) { env.compileLib(s, opts) }

  Obj? compileData(Str s, Dict? opts := null) { env.compileData(s, opts) }

  static Dict nameDictEmpty() { MNameDict.empty }

  RemoteEnv initRemote()
  {
    local := XetoEnv.cur
    server := TestServer(local)
    client := TestClient(server)

    envRef = client.bootRemoteEnv

    verifyEq(env.names.maxCode, local.names.maxCode)
    verifyEq(env.names.toName(3), local.names.toName(3))
    verifyEq(env.names.toName(env.names.maxCode), local.names.toName(env.names.maxCode))

    return env
  }

  Void verifyFitsExplain(Obj? val, Spec spec, Str[] expected)
  {
    cx := TextContext()
    hits := XetoLogRec[,]
    explain := |XetoLogRec rec| { hits.add(rec) }
    opts := Etc.dict1("explain", Unsafe(explain))
    env.fits(cx, val, spec, opts)
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
  new make(MEnv env)
  {
    this.env = env
    this.io  = XetoBinaryIO.makeServer(env)
  }

  const MEnv env
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

  RemoteEnv? env() { envRef.val }
  const AtomicRef envRef := AtomicRef()

  XetoBinaryIO io() { env.io }

  RemoteEnv bootRemoteEnv()
  {
    buf := Buf()
    libs := server.env.registry.list.findAll { it.isLoaded }.map { it.get }
    server.io.writer(buf.out).writeBoot(server.env, libs)
    // echo("--- init remote bootstrap size = $buf.size bytes ---")

    env := RemoteEnv.boot(buf.flip.in, this)
    envRef.val = env
    return env
  }

  override Void loadLib(Str name, |Err?, Lib?| f)
  {
    serverLib := server.env.lib(name, false)
    if (serverLib == null) { f(UnknownLibErr(name), null); return }

    buf := Buf()
    server.io.writer(buf.out).writeLib(serverLib)
    echo("   --- load lib $name size = $buf.size bytes ---")

    clientLib := io.reader(buf.flip.in).readLib(env)
    f(null, clientLib)
  }
}

