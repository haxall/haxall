//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Nov 2026  Matthew Giannini  Creation
//

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
    lib := (ConnLib)addLib("modbus")
    (rt.dir + `modbus.csv`).out.print(
      Str<|name,addr,data,rw
           ping,40001,u2,r|>).flush.close

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
    }
    finally listener.close
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
