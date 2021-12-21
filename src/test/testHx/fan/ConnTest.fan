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
    addLib("conn")
    verifyModel("haystack", "haystack", "lcwhx")
  }

  Void verifyModel(Str libName, Str prefix, Str flags)
  {
    lib := (ConnLib)rt.libs.add(libName)
    lib.spi.sync

    m := lib.model
    verifyEq(m.name, libName)
    verifyEq(m.connTag, prefix+"Conn")
    verifyEq(m.connRefTag, prefix+"ConnRef")

    verifyEq(m.hasLearn,    flags.contains("l"), "$libName learn")
    verifyEq(m.hasCur,      flags.contains("c"), "$libName cur")
    verifyEq(m.hasWrite,    flags.contains("w"), "$libName write")
    verifyEq(m.hasHis,      flags.contains("h"), "$libName his")

    verifyEq(m.writeLevelTag !== null, flags.contains("x"), "$libName writeLevel")
  }

//////////////////////////////////////////////////////////////////////////
// Service
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testService()
  {
    verifyNilService
    verifyEq(rt.conns.list.size, 0)

    addLib("haystack")
    verifyEq(rt.conns.list.size, 1)
    verifyConnService("haystack", "chwl")

    addLib("sql")
    verifyEq(rt.conns.list.size, 2)
    verifyConnService("haystack", "chwl")
    verifyConnService("sql", "h")
  }

  private Void verifyNilService()
  {
    c := rt.conns
    verifyEq(c.typeof.name, "NilConnRegistryService")
    verifyEq(c.list.size, 0)

    name := "haystack"
    verifyEq(c.byName(name, false), null)
    verifyErr(Err#) { c.byName(name) }
    verifyErr(Err#) { c.byName(name, true) }

    conn := Etc.emptyDict
    verifyEq(c.byConn(conn, false), null)
    verifyErr(Err#) { c.byConn(conn) }
    verifyErr(Err#) { c.byConn(conn, true) }

    pt := Etc.emptyDict
    verifyEq(c.byPoint(pt, false), null)
    verifyErr(Err#) { c.byPoint(pt) }
    verifyErr(Err#) { c.byPoint(pt, true) }
  }

  private HxConnService verifyConnService(Str name, Str flags)
  {
    c := rt.conns
    x := c.byName(name)
    verify(c.list.containsSame(x))
    verify(rt.services.getAll(HxConnService#).contains(x))

    verifyEq(x.name, name)
    verifyEq(x.connTag,    "${name}Conn")
    verifyEq(x.connRefTag, "${name}ConnRef")
    verifyEq(x.pointTag,   "${name}Point")
    verifyEq(x.curTag,     flags.contains("c") ? "${name}Cur" : null)
    verifyEq(x.hisTag,     flags.contains("h") ? "${name}His" : null)
    verifyEq(x.writeTag,   flags.contains("w") ? "${name}Write" : null)
    verifyEq(x.hasCur,     flags.contains("c"))
    verifyEq(x.hasHis,     flags.contains("h"))
    verifyEq(x.hasWrite,   flags.contains("w"))
    verifyEq(x.hasLearn,   flags.contains("l"))

    conn := Etc.makeDict(["id":Ref.gen, "${name}Conn":m])
    verifySame(c.byConn(conn), x)

    pt := Etc.makeDict(["${name}ConnRef":conn.id])
    verifySame(c.byPoint(pt), x)
    verifySame(c.byPoints([pt]), x)

    return x
  }
}