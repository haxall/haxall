//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Apr 2016  Brian Frank       Creation
//   20 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using axon
using haystack
using hx

**
** Axon library
**
@NoDoc
const class PlatformSerialFuncs
{
  ** List serial ports available and current status
  @Axon { admin = true }
  static Grid platformSerialPorts()
  {
    gb := GridBuilder()
    gb.addCol("name").addCol("device").addCol("connState").addCol("proj").addCol("owner")
    lib.ports.each |p|
    {
      gb.addRow([p.name, p.device, p.isOpen ? "open" : "closed", p.rt?.name, p.owner?.id])
    }
    return gb.toGrid
  }

  private static HxContext curContext() { HxContext.curHx }

  private static PlatformSerialLib lib() {  curContext.rt.lib("platformSerial") }
}

