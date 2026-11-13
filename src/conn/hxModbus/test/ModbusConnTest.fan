//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Nov 2026  Matthew Giannini  Creation
//

using concurrent
using inet
using haystack
using hx
using hxConn

**
** ModbusConnTest
**
class ModbusConnTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testOpen()
  {
    lib := addModbus

    // unreachable device fails the open, never reporting ok
    port := TcpListener().bind(IpAddr("127.0.0.1"), null)
    portNum := port.localPort
    port.close
    c := addConn(lib, portNum)
    c.ping.get
    verifyOpen(c, false)
    verifyEq(c.status, ConnStatus.down)
    verifyEq(c.state,  ConnState.closed)

    // reachable device opens, then the ping fails on the read
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    try
    {
      c = addConn(lib, listener.localPort)
      f := c.ping
      listener.accept.close
      f.get
      verifyOpen(c, true)
      verifyEq(c.state, ConnState.closed)

      // the read failure names its cause
      err := rt.db.readById(c.id)["connErr"].toStr
      verify(err.startsWith("sys::IOErr: Low-level IO error: "), err)
    }
    finally listener.close
  }

//////////////////////////////////////////////////////////////////////////
// Conn Updated
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testConnUpdated()
  {
    lib := addModbus
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    unit := AtomicInt(-1)
    serve(listener, unit)
    try
    {
      // watch a point so hxConn keeps the conn open
      c  := addConn(lib, listener.localPort)
      pt := addRec(["dis":"Ping", "point":m, "kind":"Number",
                    "modbusConnRef":c.id, "modbusCur":"ping"])
      rt.sync
      rt.watch.open("test").add(pt.id)
      syncConn(c)
      verifyEq(c.state, ConnState.open)
      c.ping.get
      verifyEq(unit.val, 1)

      // an edit closes the conn, and the reopen uses the new settings
      commit(rt.db.readById(c.id), ["modbusSlave":n(2)])
      syncConn(c)
      verifyEq(c.state, ConnState.closed)
      c.forceHouseKeeping.get
      syncConn(c)
      verifyEq(c.state, ConnState.open)
      c.ping.get
      verifyEq(unit.val, 2)

      // enabling reopens from the new rec before onConnUpdated,
      // which must leave that open conn alone
      commit(rt.db.readById(c.id), ["disabled":m])
      syncConn(c)
      verifyEq(c.state, ConnState.closed)
      commit(rt.db.readById(c.id), ["disabled":Remove.val])
      syncConn(c)
      verifyEq(c.state, ConnState.open)
    }
    finally listener.close
  }

  ** Answer every read on listener with zeros, recording the unit id
  private Void serve(TcpListener listener, AtomicInt unit)
  {
    Actor(ActorPool()) |Unsafe msg->Obj?|
    {
      TcpListener l := msg.val
      while (true)
      {
        TcpSocket? s
        try s = l.accept
        catch (Err e) return null
        try
        {
          while (true)
          {
            req := s.in.readBufFully(null, 12)
            tx  := req.readU2
            req.readU2; req.readU2
            unit.val = req.read
            fc  := req.read
            req.readU2
            count := req.readU2
            out := s.out
            out.writeI2(tx).writeI2(0).writeI2(3 + count * 2)
            out.write(unit.val).write(fc).write(count * 2)
            count.times { out.writeI2(0) }
            out.flush
          }
        }
        catch (IOErr e) {}
        finally s.close
      }
      return null
    }.send(Unsafe(listener))
  }

//////////////////////////////////////////////////////////////////////////
// Support
//////////////////////////////////////////////////////////////////////////

  private ConnLib addModbus()
  {
    lib := (ConnLib)addLib("modbus")
    (rt.dir + `modbus.csv`).out.print(
      Str<|name,addr,data,rw
           ping,40001,u2,r|>).flush.close
    return lib
  }

  private Void syncConn(Conn c)
  {
    rt.sync
    c.sendSync(HxMsg("sync"))
  }

  private Conn addConn(ConnLib lib, Int port)
  {
    rec := addRec(["dis":"Modbus", "modbusConn":m,
                   "uri":`modbus-tcp://127.0.0.1:${port}/`,
                   "modbusSlave":n(1), "modbusRegMapUri":`modbus.csv`])
    rt.sync
    c := lib.conn(rec.id)
    c.trace.enable
    return c
  }

  private Void verifyOpen(Conn c, Bool ok)
  {
    phases := c.trace.read.findAll |x| { x.type == "phase" }.map |x->Str| { x.msg }
    verifyEq(phases.contains("open ok"),  ok)
    verifyEq(phases.contains("open err"), !ok)
  }
}
