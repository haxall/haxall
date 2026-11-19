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

  @HxRuntimeTest
  Void testOpenRtuTcp()
  {
    lib := addModbus
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    TcpSocket? s
    try
    {
      // the gateway accepts, but the slave behind it never answers, so the
      // open fails rather than report ok until the first poll
      rec := addRec(["dis":"Modbus", "modbusConn":m,
                     "uri":`modbus-rtutcp://127.0.0.1:${listener.localPort}/`,
                     "modbusSlave":n(1), "modbusRegMapUri":`modbus.csv`,
                     "modbusReadTimeout":n(200, "ms")])
      rt.sync
      c := traced(lib.conn(rec.id))
      f := c.ping
      s = listener.accept
      f.get
      verifyOpen(c, false)
      verifyEq(c.status, ConnStatus.down)
    }
    finally { s?.close; listener.close }
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

//////////////////////////////////////////////////////////////////////////
// Lib Restart
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testLibRestart()
  {
    addLib("platformSerial")
    lib := addModbus
    rec := addRec(["dis":"RTU", "modbusConn":m, "uri":`modbus-rtu://test-9600-8n1-none`,
                   "modbusSlave":n(1), "modbusRegMapUri":`modbus.csv`,
                   "modbusReadTimeout":n(100, "ms")])
    rt.sync
    verifySilentRtu(lib.conn(rec.id))

    // a restarted lib opens the serial port as itself, not as the lib it
    // replaced, whose rec is gone
    rt.libs.remove("modbus")
    rt.sync
    lib = addModbus
    verifySilentRtu(lib.conn(rec.id))
  }

  ** The test port never answers, so the open gets as far as the slave:
  ** the port opened, but the open fails rather than report ok
  private Void verifySilentRtu(Conn c)
  {
    traced(c).ping.get
    verifyOpen(c, false)
    verifyEq(rt.db.readById(c.id)["connErr"], "hxModbus::ModbusTimeoutErr: Response timeout after 100ms")
  }

//////////////////////////////////////////////////////////////////////////
// Busy Link
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testCloseBusyLink()
  {
    lib := (ModbusLib)addModbus
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    TcpSocket? s
    try
    {
      // a device which never answers keeps the link busy
      uri := `modbus-tcp://127.0.0.1:${listener.localPort}/`
      dev := ModbusDev
      {
        it.rec          = Etc.emptyDict
        it.uri          = uri
        it.slave        = 1
        it.regMap       = ModbusRegMap.fromFile(rt.dir + `modbus.csv`)
        it.frameDelay   = 0sec
        it.readTimeout  = 10sec
        it.timeout      = 10sec
        it.log          = lib.log
      }
      link := lib.links.get(uri)
      Actor(ActorPool()) |->| { link.ping(dev) }.send(null)
      s = listener.accept

      // close gives up waiting rather than hold the conn in closing
      t1 := Duration.now
      link.close(200ms)
      verify(Duration.now - t1 < 2sec)
    }
    finally { s?.close; listener.close }
  }

//////////////////////////////////////////////////////////////////////////
// Echo Mismatch
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testEchoMismatch()
  {
    lib := (ModbusLib)addModbus
    listener := TcpListener().bind(IpAddr("127.0.0.1"), null)
    serve(listener, AtomicInt(-1), true)
    try
    {
      // a write the device echoes back wrong fails only the write
      c := addConn(lib, listener.localPort)
      verifyErrMsg(ModbusEchoErr#, "Address mismatch 1 != 2") { lib.write(c.id, "sp", n(5)) }
      verifyEq(c.state, ConnState.open)

      // the whole response was read, so the next request is still in sync
      verifyEq(lib.read(c.id, ["ping"]).first->val, n(0))
      verifyEq(c.state, ConnState.open)
    }
    finally listener.close
  }

  ** Answer every read on listener with zeros, recording the unit id. Echo
  ** single writes, off by one address if badEcho.
  private Void serve(TcpListener listener, AtomicInt unit, Bool badEcho := false)
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
            addr  := req.readU2
            count := req.readU2
            out := s.out
            if (fc == 0x05 || fc == 0x06)
            {
              out.writeI2(tx).writeI2(0).writeI2(6)
              out.write(unit.val).write(fc).writeI2(badEcho ? addr + 1 : addr).writeI2(count)
            }
            else
            {
              out.writeI2(tx).writeI2(0).writeI2(3 + count * 2)
              out.write(unit.val).write(fc).write(count * 2)
              count.times { out.writeI2(0) }
            }
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
           ping,40001,u2,r
           sp,40002,u2,rw|>).flush.close
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
    return traced(lib.conn(rec.id))
  }

  private Conn traced(Conn c)
  {
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
