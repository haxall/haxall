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

  ** Never call this! Use `ModbusLinkMgr.get`.
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

  ** Open the transport to the given device without reading anything,
  ** or do nothing if it is already open. Throws error if open failed.
  Void open(ModbusDev dev)
  {
    actor.send(HxMsg("open", dev)).get(dev.timeout)
  }

  ** Convenience for [read] with the device's ping register. Throws error
  ** if the device has no ping register configured, or if the read failed.
  Void ping(ModbusDev dev)
  {
    ping := dev.pingReg ?: throw FaultErr("Missing 'modbusPingAddr' tag or 'ping' register")
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

  ** Read a block of registers from given device. The device's read timeout
  ** bounds the wait for its response; this wait also covers the queue of
  ** every other conn on this link, so it is bounded by the conn timeout.
  Void readBlock(ModbusDev dev, ModbusBlock block)
  {
    actor.send(HxMsg("read", dev, block)).get(dev.timeout)
  }

  ** Write to a register to given device. See `readBlock` for timeouts.
  Void write(ModbusDev dev, ModbusReg reg, Obj val)
  {
    actor.send(HxMsg("write", dev, reg, val)).get(dev.timeout)
  }

  ** Release this link. The transport is shared by every conn using this uri,
  ** so only tear it down once the last user is done with it. The stale link
  ** reaper in `ModbusLinkMgr` is the backstop if a release is ever missed.
  ** See `close` for timeout.
  internal Void release(Duration timeout)
  {
    if (_users.decrementAndGet > 0) return
    close(timeout)
  }

  ** Force this link closed regardless of how many conns are using it. Used
  ** when the transport itself is broken and everyone needs it recycled.
  ** Wait at most timeout for the link to finish its current request: a
  ** link stuck in a call that never returns must not hold its conns in
  ** the closing state. The close stays queued and runs once it is free.
  internal Void close(Duration timeout)
  {
    try actor.send(HxMsg("close")).get(timeout)
    catch (TimeoutErr err) ext.log.err("Link busy, close not confirmed: ${uri}")
  }

  ** Register a conn as using this link.
  internal Void addUser() { _users.incrementAndGet }

  ** Is this link free of any conn holding it.
  internal Bool isUnused() { _users.val <= 0 }

//////////////////////////////////////////////////////////////////////////
// Actor Impl
//////////////////////////////////////////////////////////////////////////

  ** Actor callback.
  private Obj? actorReceive(HxMsg m)
  {
    _touched.val = Duration.nowTicks
    switch (m.id)
    {
      case "open":  _open(m.a); return null
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
          serial := ext.proj.ext("hx.platform.serial", false) as PlatformSerialExt
          if (serial == null) throw FaultErr("RTU not supported")
          config := SerialConfig.fromStr(uri.host)
          tx = ModbusRtuTransport(serial.open(ext.proj, ext.settings, config))

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
      master.quietTime = dev.frameDelay
      master.responseTimeout = dev.readTimeout
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
      sb := StrBuf().add("Low-level IO error: ${err.msg}\n")
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
    catch (ModbusTimeoutErr err)
    {
      // a silent device faults its conn, so hxConn backs off before polling
      // it again rather than charge every poll the full timeout
      throw err
    }
    catch (Err err)
    {
// echo("# [$Time.now] [Err] $err.msg")
      ex := Err("${err.msg} [${block.regs.first.addr} count=${block.size}]", err)
      block.resolveErr(ex)

      // the block absorbs the error so the conn stays up, but an unframed
      // transport still has the rest of the bad response queued; recycle it
      // rather than read that tail as the next response
      if (!master.isFramed) _close(master)
    }
    return null
  }

  ** Actor write.
  private Obj? _write(ModbusMaster master, ModbusDev dev, ModbusReg reg, Obj val)
  {
    if (!reg.writable) throw ArgErr("Register is not writable")

    type := reg.addr.type
    addr := reg.addr.num - 1

    master.quietTime = dev.frameDelay
    master.responseTimeout = dev.writeTimeout
    master.withTrace(dev.log)
    {
      if (type == ModbusAddrType.coil)
      {
        if (dev.forceMultiCoils) master.writeCoils(dev.slave, addr, [(Bool)val])
        else master.writeCoil(dev.slave, addr, val)
      }
      else
      {
        if (reg.scale != null) val = reg.scale.inverse(val)
        regs := reg.data.toRegs(val)

        if (reg.data is ModbusBitData)
        {
          bit := (ModbusBitData)reg.data
          cur := master.readHoldingRegs(dev.slave, addr, reg.data.size).first
          regs[0] = val==true ? cur.or(bit.mask) : cur.and(bit.mask.not)
        }

        if (regs.size == 1 && !dev.forceMultiRegs) master.writeHoldingReg(dev.slave, addr, regs.first)
        else master.writeHoldingRegs(dev.slave, addr, regs)
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
  private const AtomicInt _users := AtomicInt(0)
}

**************************************************************************
** ModbusLinkMgr
**************************************************************************

**
** ModbusLinkMgr manages the links for the conns of one ModbusExt. Conns of
** that ext with the same uri share a link, but exts never share: each ext
** opens its serial ports as itself, and stopping it closes its links.
**
@NoDoc internal const class ModbusLinkMgr
{
  ** Constructor
  new make(ModbusExt ext)
  {
    this.ext   = ext
    this.pool  = ActorPool { it.name = "${ext.proj.name}-ModbusLink" }
    this.actor = Actor(pool) |m| { actorReceive(m) }
  }

  private const HxMsg poll := HxMsg("poll")
  private const Duration pollFreq  := 1min
  private const Int staleTime := 1min.ticks
  private const Duration closeTimeout := 5sec

  private const ModbusExt ext
  private const ActorPool pool
  private const Actor actor

  ** Start polling for stale links
  Void start() { actor.sendLater(pollFreq, poll) }

  ** Close every link and kill the pool
  Void stop()
  {
    actor.send(HxMsg("stop")).get(1min)
    pool.kill
  }

  ** Get the link for uri and add a user to it. Every caller must
  ** eventually balance this with a `ModbusLink.release`.
  ModbusLink get(Uri uri) { actor.send(HxMsg("get", uri)).get(5sec) }

  ** Actor callback.
  private Obj? actorReceive(HxMsg m)
  {
    // init fields
    [Uri:ModbusLink]? map := Actor.locals["m"]
    if (map == null) Actor.locals["m"] = map = Uri:ModbusLink[:]

    // respond to message
    switch (m.id)
    {
      case "get":
        Uri uri := m.a
        link := map[uri]
        if (link == null) map[uri] = link = ModbusLink(pool, ext, uri)
        link.addUser
        return link

      case "poll":
        try { _check(map) }
        finally { actor.sendLater(pollFreq, poll) }
        return null

      case "stop":
        map.each |link| { link.close(closeTimeout) }
        map.clear
        return null

      default: return null
    }
  }

  ** Actor check stale links. Never drop a link a conn is still holding, or
  ** the next `get` for that uri would build a second link - and a second
  ** socket onto the same wire, which defeats both the serialization and the
  ** frame delay. Releasing the last user already closes the transport.
  private Void _check(Uri:ModbusLink map)
  {
    now  := Duration.nowTicks
    map.keys.each |k|
    {
      link := map[k]
      diff := now - link.touched
      if (diff >= staleTime && link.isUnused) { link.close(closeTimeout); map.remove(k) }
    }
  }
}
