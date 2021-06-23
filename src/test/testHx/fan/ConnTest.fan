//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2021  Brian Frank  Creation
//

using concurrent
using haystack
using axon
using folio
using hx
using hxConn

**
** ConnTest
**
class ConnTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Model
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testModel()
  {
    rt.libs.add("hxConn")
    verifyModel("hxHaystack", "haystack", "lcwhx")
  }

  Void verifyModel(Str libName, Str prefix, Str flags)
  {
    lib := (ConnLib)rt.libs.add(libName)
    lib.spi.sync

    m := lib.model
    verifyEq(m.name, libName)
    verifyEq(m.connTag, prefix+"Conn")
    verifyEq(m.connRefTag, prefix+"ConnRef")
    verifyEq(m.pingFunc, prefix+"Ping")

    verifyEq(m.hasDiscover, flags.contains("d"), "$libName discover")
    verifyEq(m.hasLearn,    flags.contains("l"), "$libName learn")
    verifyEq(m.hasCur,      flags.contains("c"), "$libName cur")
    verifyEq(m.hasWrite,    flags.contains("w"), "$libName write")
    verifyEq(m.hasHis,      flags.contains("h"), "$libName his")

    verifyEq(m.writeLevelTag !== null, flags.contains("x"), "$libName writeLevel")
  }
}