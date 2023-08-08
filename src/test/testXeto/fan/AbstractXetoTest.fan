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
  Void verifyAllEnvs(|XetoEnv| f)
  {
    // first test local
    envRef = XetoEnv.cur
    f(env)

    // test remote
    envRef = initRemote
    f(env)
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
echo("--- init remote ---")
    local := XetoEnv.cur
    buf := Buf()
    serverTransport := XetoTransport.writeEnvBootstrap(local, buf.out)
echo("--- $buf.size ---")
echo(buf.toHex)

    envRef = XetoTransport.readEnvBootstrap(buf.flip.in)

    verifyEq(env.names.maxCode, local.names.maxCode)
    verifyEq(env.names.toName(3), local.names.toName(3))
    verifyEq(env.names.toName(env.names.maxCode), local.names.toName(env.names.maxCode-1))

    return env
  }
}