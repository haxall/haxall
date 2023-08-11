//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//

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
    env.libAsync(lib) |x|
    {
      if (x == null) throw Err("Lib not found: $lib")
      f(env)
    }
  }

  XetoEnv env()
  {
    if (envRef == null) envRef = XetoEnv.cur
    return envRef
  }

  private XetoEnv? envRef

  Lib compileLib(Str s) { env.compileLib(s) }

  Obj? compileData(Str s) { env.compileData(s) }

  static Dict nameDictEmpty() { MNameDict.empty }

  RemoteEnv initRemote()
  {
    local := XetoEnv.cur
    server := TestServer(local)
    client := TestClient(server)

    buf := Buf()
    XetoBinaryWriter(server, buf.out).writeBoot
echo("--- init remote bootstrap size = $buf.size bytes ---")
//echo(buf.toHex)


    envRef = client.boot(buf.flip.in)

    verifyEq(env.names.maxCode, local.names.maxCode)
    verifyEq(env.names.toName(3), local.names.toName(3))
    verifyEq(env.names.toName(env.names.maxCode), local.names.toName(env.names.maxCode))

    return env
  }
}

**************************************************************************
** TestClient
**************************************************************************

@Js
const class TestClient : XetoClient
{
  new make(TestServer server) { this.server = server }

  const TestServer server

  override Void loadLib(Str qname, |Lib?| f)
  {
    serverLib := server.env.lib(qname, false)
    if (serverLib == null) { f(null); return }

    buf := Buf()
    XetoBinaryWriter(server, buf.out).writeLib(serverLib)
    echo("--- load lib $qname size = $buf.size bytes ---")

    clientLib := XetoBinaryReader(this, buf.flip.in).readLib
    f(clientLib)
  }
}

**************************************************************************
** TestServer
**************************************************************************

@Js
const class TestServer : XetoServer
{
  new make(MEnv env) : super(env) {}
}