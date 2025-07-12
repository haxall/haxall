//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Aug 2013  Andy Frank       Creation
//    3 Jun 2016  Brian Frank      Port to 3.0
//   26 Jan 2022  Matthew Giannini Redesign for Haxall
//

using xeto
using haystack
using hx

class SerialSpiTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Config
//////////////////////////////////////////////////////////////////////////

  Void testConfig()
  {
    verifyEq(SerialConfig { it.name = "a" }, SerialConfig { it.name = "a" })

    verifyConfig(SerialConfig { it.name = "a"; baud=9600 })
    verifyConfig(SerialConfig { it.name = "a"; parity =  SerialConfig.parityEven })
    verifyConfig(SerialConfig { it.name = "a"; data=7 })
    verifyConfig(SerialConfig { it.name = "a"; stop=2 })
    verifyConfig(SerialConfig { it.name = "a"; flow   = SerialConfig.flowXonXoff })
    verifyConfig(SerialConfig {
        it.name   = "foo"
        it.baud   = 9600
        it.data   = 7
        it.parity = SerialConfig.parityEven
        it.stop   = 2
        it.flow   = SerialConfig.flowXonXoff
      })

    verifyErr(ArgErr#) { x := SerialConfig { it.name = "foo-bar" } }
    verifyErr(ArgErr#) { x := SerialConfig { it.name = "foo bar" } }
    verifyErr(ArgErr#) { x := SerialConfig { it.name = "foo"; it.data = 3 } }
  }

  Void verifyConfig(SerialConfig s)
  {
    x := SerialConfig { it.name = s.name }
    verifyNotEq(x, s)
    verifyEq(SerialConfig.fromStr(s.toStr), s)
  }

//////////////////////////////////////////////////////////////////////////
// Spi
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSpi()
  {
    PlatformSerialExt? ext := rt.libsOld.get("platformSerial", false)
    if (ext == null) ext = rt.libsOld.add("platformSerial")

    // initial state
    s := ext.port("test")
    verifyEq(ext.ports.size, 1)
    verifyNotNull(ext.ports.indexSame(s))
    verifyStatus(ext, s, "test", "/test", null)
    verifyEq(ext.port("badone", false), null)
    verifyErr(UnknownSerialPortErr#) { ext.port("badone") }

    // open a port
    conn := addRec(["dis":"MyConn"])
    cfg := SerialConfig { it.name = "test" }
    p := ext.open(rt, conn, cfg)
    verifyPort(p, cfg, false)
    verifyStatus(ext, s, "test", "/test", conn)

    // open errors
    verifyErr(SerialPortAlreadyOpenErr#) { ext.open(rt, conn, SerialConfig { it.name = "test" } ) }
    verifyErr(UnknownSerialPortErr#) { ext.open(rt, conn, SerialConfig { it.name = "foobar" } ) }

    // verify serialPorts()
    grid := (Grid)eval("platformSerialPorts()")
    verifyEq(grid.size, 1)
    verifyEq(grid[0]["name"],   "test")
    verifyEq(grid[0]["device"], "/test")
    verifyEq(grid[0]["status"], "open")
    verifyEq(grid[0]["owner"],  conn.id)

    // close the port
    p.close
    verifyPort(p, cfg, true)
    verifyStatus(ext, s, "test", "/test", null)
  }

  Void verifyStatus(PlatformSerialExt ext, SerialPort p, Str n, Str d, Dict? owner)
  {
    verifyEq(p.name,     n)
    verifyEq(p.device,   d)
    verifyEq(p.isOpen,   owner != null)
    verifyEq(p.isClosed, owner == null)
    verifyEq(p.rt,       owner == null ? null : this.rt)
    verifyValEq(p.owner, owner)

    Grid grid := eval("platformSerialPorts()")
    // grid.dump

    verifyEq(grid.size, ext.ports.size)
    row := grid.find |r| { r->name == n }
    verifyEq(row["device"], d)
    verifyEq(row["status"], owner == null ? "closed" : "open")
    verifyEq(row["proj"],   owner == null ? null : rt.name)
    verifyEq(row["owner"],  owner == null ? null : owner.id)
  }

  Void verifyPort(SerialSocket p, SerialConfig c, Bool isClosed)
  {
    verifyEq(p.name, c.name)
    verifySame(p.config, c)
    verifyEq(p.isClosed, isClosed)
  }
}

