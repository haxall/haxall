//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Dec 2016  Andy Frank       Creation
//  14 Jan 2022  Matthew Giannini Redesign for Haxall
//

using concurrent
using inet
using haystack
using hx
using hxPlatformSerial

**************************************************************************
** ModbusLink
**************************************************************************

**
** ModbusLink manages communication to all devices for a given Uri endpoint.
**
@NoDoc const class ModbusLink
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Get the ModbusLink for the given URI.
  static ModbusLink get(Uri uri) { ModbusLinkMgr.cur.open(uri) }

  ** Never call this!
  @NoDoc internal new make(ActorPool pool, ModbusExt ext, Uri uri)
  {
    this.ext   = ext
    this.uri   = uri
    this.name  = "ModbusLink-$uri"
    this.actor = Actor(pool) |m| { actorReceive(m) }
  }

//////////////////////////////////////////////////////////////////////////
// Public API
//////////////////////////////////////////////////////////////////////////

  ** Ticks last touched.
  Int touched() { _touched.val }
  private const AtomicInt _touched := AtomicInt(0)

  ** Convenience for `read` with the 'ping' register. Throws error
  ** if 'ping' register not found, or if read failed.
  Void ping(ModbusDev dev)
  {
    ping := dev.regMap.reg("ping", false) ?: throw FaultErr("Missing ping register")
    val  := read(dev, ping)
    if (val is Err) throw val
  }

  ** Read a register from given device.
  Obj read(ModbusDev dev, ModbusReg reg)
  {
    block := ModbusBlock([reg])
    readBlock(dev, block)
    return block.vals.first
  }

  ** Read a block of registers from given device.
  Void readBlock(ModbusDev dev, ModbusBlock block)
  {
    actor.send(HxMsg("read", dev, block)).get(dev.readTimeout)
  }

  ** Write to a register to given device.
  Void write(ModbusDev dev, ModbusReg reg, Obj val)
  {
    actor.send(HxMsg("write", dev, reg, val)).get(dev.writeTimeout)
  }

  ** Close this link.
  internal Void close()
  {
    actor.send(HxMsg("close")).get
  }

//////////////////////////////////////////////////////////////////////////
// Actor Impl
//////////////////////////////////////////////////////////////////////////

  ** Actor callback.
  private Obj? actorReceive(HxMsg m)
  {
    _touched.val = Duration.nowTicks
    switch (m.id)
    {
      case "read":  return _read(_open(m.a), m.a, m.b).toImmutable
      case "write": return _write(_open(m.a), m.a, m.b, m.c)
      case "close": return _close(Actor.locals["m"])
      default:      return null
    }
  }

  ** Actor open master.
  private ModbusMaster _open(ModbusDev dev)
  {
    ModbusMaster? master := Actor.locals["m"]
    if (master == null)
    {
      ModbusTransport? tx
      switch (uri.scheme)
      {
        case "modbus-tcp":    tx = ModbusTcpTransport(IpAddr(uri.host),    uri.port, dev.timeout)
        case "modbus-rtutcp": tx = ModbusRtuTcpTransport(IpAddr(uri.host), uri.port, dev.timeout)
        case "modbus-rtu":
          serial := ext.rt.ext("hx.platform.serial", false) as PlatformSerialExt
          if (serial == null) throw FaultErr("RTU not supported")
          config := SerialConfig.fromStr(uri.host)
          tx = ModbusRtuTransport(serial.open(ext.rt, ext.rec, config))

        default: throw FaultErr("Invalid scheme: $uri.scheme")
      }
      tx.log = ext.log
      Actor.locals["m"] = master = ModbusMaster(tx)
    }
    master.open
    return master
  }

  ** Actor close master.
  private Obj? _close(ModbusMaster? master)
  {
    master?.close
    Actor.locals.remove("m")
    return null
  }

  ** Actor read.
  private Obj? _read(ModbusMaster master, ModbusDev dev, ModbusBlock block)
  {
    try
    {
      master.withTrace(dev.log)
      {
        start := block.start - 1
        size  := block.size

  // echo("# [$Time.now] link.read ? $start-${start+size} [$size]")

        Obj? raw
        switch (block.type)
        {
          case ModbusAddrType.coil:          raw = master.readCoils(dev.slave, start, size)
          case ModbusAddrType.discreteInput: raw = master.readDiscreteInputs(dev.slave, start, size)
          case ModbusAddrType.inputReg:      raw = master.readInputRegs(dev.slave, start, size)
          case ModbusAddrType.holdingReg:    raw = master.readHoldingRegs(dev.slave, start, size)
        }

  // echo("# [$Time.now] link.read @ $start-${start+size} [$size] == $raw")

        block.resolve(raw)
      }
    }
    catch (IOErr err)
    {
// echo("# [$Time.now] [IOErr] $err.msg")
      // Assume low-level I/O error; propogate up so connector
      // forces a close and reopen.  Make sure not to throw an
      // IOErr for application errors, so we can localize errs
      // to just the requesting block
      sb := StrBuf().add("Low-level IO error\n")
        .add("Device: ${dev.uri} [slave=${dev.slave}]\n")
        .add("Block: [type=${block.type}]\n")
        .add("Registers:\n")
      block.regs.each |reg|
      {
        rw := reg.readable ? "r" : ""
        if (reg.writable) rw = rw + "w"
        sb.add("  ${reg.name} ${reg.dis} [addr=${reg.addr}] [data=${reg.data}] [size=${reg.size}] [${rw}]\n")
      }
      dev.log.err(sb.toStr, err)
      throw IOErr(sb.toStr, err)
    }
    catch (Err err)
    {
// echo("# [$Time.now] [Err] $err.msg")
      ex := Err("$err.msg [$block.regs.first.addr count=$block.size]", err)
      block.resolveErr(ex)
    }
    return null
  }

  ** Actor write.
  private Obj? _write(ModbusMaster master, ModbusDev dev, ModbusReg reg, Obj val)
  {
    if (!reg.writable) throw ArgErr("Register is not writable")

    type := reg.addr.type
    addr := reg.addr.num - 1

    master.withTrace(dev.log)
    {
      if (type == ModbusAddrType.coil)
      {
        master.writeCoil(dev.slave, addr, val)
      }
      else
      {
        sf := reg.scale?.factor
        if (sf != null) val = reg.scale.inverse(val, sf)
        regs := reg.data.toRegs(val)

        if (reg.data is ModbusBitData)
        {
          bit := (ModbusBitData)reg.data
          cur := master.readHoldingRegs(dev.slave, addr, reg.data.size).first
          regs[0] = val==true ? cur.or(bit.mask) : cur.and(bit.mask.not)
        }

        if (dev.forceWriteMultiple)
          master._writeHoldingRegs(dev.slave, addr, regs)
        else
          master.writeHoldingRegs(dev.slave, addr, regs)
      }
    }

    return null
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const ModbusExt ext
  private const Uri uri
  private const Str name
  private const Actor actor
}

**************************************************************************
** ModbusLinkMgr
**************************************************************************

@NoDoc internal const class ModbusLinkMgr
{
  ** Init ModbusLinkMgr if needed.
  static Void init(ModbusExt ext)
  {
    if (curRef.val == null) curRef.val = ModbusLinkMgr(ext)
  }

  ** Stop the link manager. It can no longer be used after this
  ** and must be re-inited
  static Void stop()
  {
    // if never initialized, then nothing to do
    mgr := curRef.val as ModbusLinkMgr
    if (mgr == null) return

    // we can't actually stop the pool because it is being shared
    // across projects.
    // mgr.pool.kill
    // curRef.val = null
  }

  ** ModbusLinkMgr instance for this VM.
  static ModbusLinkMgr cur() { curRef.val }
  private static const AtomicRef curRef := AtomicRef(null)

  ** Private ctor.
  private new make(ModbusExt ext)
  {
    this.ext   = ext
    this.pool  = ActorPool { name="ModbusLink" }
    this.actor = Actor(pool) |m| { actorReceive(m) }
    this.actor.sendLater(pollFreq, poll)
  }

  ** Open a ModbusLink for given uri.
  ModbusLink open(Uri uri) { actor.send(HxMsg("open", uri)).get(5sec)  }

  ** Actor callback.
  private Obj? actorReceive(HxMsg m)
  {
    // init fields
    [Uri:ModbusLink]? map := Actor.locals["m"]
    if (map == null) Actor.locals["m"] = map = Uri:ModbusLink[:]

    // respond to message
    switch (m.id)
    {
      case "open":
        Uri uri := m.a
        link := map[uri]
        if (link == null) map[uri] = link = ModbusLink(pool, ext, uri)
        return link

      case "poll":
        try { _check(map) }
        finally { actor.sendLater(pollFreq, poll) }
        return null

      default: return null
    }
  }

  ** Actor check stale links.
  private Void _check(Uri:ModbusLink map)
  {
    now  := Duration.nowTicks
    map.keys.each |k|
    {
      link := map[k]
      diff := now - link.touched
      if (diff >= staleTime) { link.close; map.remove(k) }
    }
  }

  private const HxMsg poll := HxMsg("poll")
  private const Duration pollFreq  := 1min
  private const Int staleTime := 1min.ticks

  private const ModbusExt ext
  private const ActorPool pool
  private const Actor actor
}

