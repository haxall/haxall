//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Sep 2026  Brian Frank  Derive from pim3
//

using concurrent
using util
using xeto
using haystack

**
** PiConns is the registry of ph.protocol and hx.conn models for a given namespace.
**
@NoDoc @Js
const class PiConns
{
  new make(Namespace ns)
  {
    this.ns = ns
    byConn := Spec:PiConn[:]
    byName := Str:PiConn[:]
    byAddr := Spec:PiConn[:]
    plugs  := toPlugs

    // map all extensions that subtype ConnExt
    connExt := ns.spec("hx.conn::ConnExt", false)
    if (connExt != null)
    {
      ns.libs.each |lib|
      {
        extRef := lib.meta["libExt"] as Ref
        if (extRef == null) return
        extSpec := ns.spec(extRef.id, false)
        if (extSpec == null) return
        if (extSpec.isa(connExt))
        {
          try
          {
            c := create(plugs, ns, lib, extSpec)
            byConn[c.conn] = c
            byName[c.name] = c
          }
          catch (Err e) Console.cur.err("PiConn map $extSpec", e)
        }
      }
    }

    // map ProtocolAddr subtypes to conn models by name: ModbusAddr -> modbus
    protocolAddr := ns.spec("ph.protocols::ProtocolAddr", false)
    if (protocolAddr != null && !byConn.isEmpty)
    {
      ns.libs.each |lib|
      {
        lib.types.each |t|
        {
          if (t.base !== protocolAddr) return
          c := byName[addrToName(t)]
          if (c != null) byAddr[t] = c
        }
      }
    }

    this.byConn = byConn
    this.byAddr = byAddr
  }

  ** Create conn model for ext using its plug subclass or base PiConn
  private static PiConn create(Str:Type plugs, Namespace ns, Lib lib, Spec ext)
  {
    plug := plugs[lib.name]
    if (plug == null) return PiConn(ns, ext)
    return plug.make([ns, ext])
  }

  ** Resolve PiConn subclass plugs from the "pi.conn" pod index
  ** where each entry is "<lib name> <type qname>"
  private static Str:Type toPlugs()
  {
    acc := Str:Type[:]
    try
    {
      Env.cur.index("pi.conn").each |str|
      {
        try
        {
          toks := str.split
          acc[toks[0]] = Type.find(toks[1])
        }
        catch (Err e) Console.cur.err("Invalid pi.conn index: $str", e)
      }
    }
    catch (Err e) {}
    return acc
  }

  ** Map addr spec name to conn model name: "ModbusAddr" -> "modbus"
  private static Str addrToName(Spec addr)
  {
    n := addr.name
    if (n.endsWith("Addr")) n = n[0..-5]
    return n.decapitalize
  }

  ** Lookup conn model for a connector spec walking base types
  PiConn? forConn(Spec? spec, Bool checked := true) { lookup(byConn, spec, checked) }

  ** Lookup conn model for a connector rec by its spec tag walking
  ** base types, else by its protocol conn marker for legacy recs
  PiConn? forConnRec(Dict rec, Bool checked := true)
  {
    spec := ns.spec((rec["spec"] as Ref)?.toStr ?: "", false)
    c := forConn(spec, false)
    if (c == null) c = byConn.find |x| { rec.has(x.connMarker) }
    if (c != null) return c
    if (checked) throw Err("No conn model for rec: " + rec["id"])
    return null
  }

  ** Lookup conn model for a protocol addr spec walking base types
  PiConn? forAddr(Spec? spec, Bool checked := true) { lookup(byAddr, spec, checked) }

  private static PiConn? lookup(Spec:PiConn map, Spec? spec, Bool checked)
  {
    for (Spec? t := spec; t != null; t = t.base)
    {
      c := map[t]
      if (c != null) return c
    }
    if (checked) throw Err("No conn model mapped: $spec")
    return null
  }

  ** Namespace this registry was built from
  const Namespace ns

  ** Map of protocol addr spec to its conn model
  const Spec:PiConn byAddr

  ** Map of connector spec to its conn model
  const Spec:PiConn byConn
}

**************************************************************************
** PiConn
**************************************************************************

**
** PiConn is used to support tooling for ph.protocol and hx.conn.
**
@NoDoc @Js
const class PiConn
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(Namespace ns, Spec ext)
  {
    this.features       = ext.meta["connFeatures"] as Dict ?: throw Err("Must define connFeatures meta on $ext")
    this.name           = features["name"]?.toStr ?: ext.lib.name.split('.').last
    this.conn           = ext.lib.type(name.capitalize + "Conn")
    this.point          = ext.lib.type(name.capitalize + "Point")
    this.connRefSlot    = point.slot("${name}ConnRef")
    this.curSlot        = point.slot("${name}Cur", false)
    this.writeSlot      = point.slot("${name}Write", false)
    this.writeLevelSlot = point.slot("${name}WriteLevel", false)
    this.hisSlot        = point.slot("${name}His", false)
    this.pollFreqSlot   = conn.slot("${name}PollFreq", false)
    this.hasLearn       = features.has("learn")
    this.hasCur         = curSlot != null
    this.hasWrite       = writeSlot != null
    this.hasHis         = hisSlot != null
  }

//////////////////////////////////////////////////////////////////////////
// Model
//////////////////////////////////////////////////////////////////////////

  ** Name of the connector such as "bacnet"
  const Str name

  ** Spec of connector "BacnetConn"
  const Spec conn

  ** Spec for points such as "BacnetPoint"
  const Spec point

  ** Point slot for the connector reference such as "bacnetConnRef"
  const Spec connRefSlot

  ** Point slot for the current address such as "bacnetCur".
  ** This field is null if current values are not supported.
  const Spec? curSlot

  ** Point slot for the write address such as "bacnetWrite".
  ** This field is null if writes are not supported.
  const Spec? writeSlot

  ** Point slot if connector requires level for pushing write to remote
  ** system (bacnet, haystack).  This field is null if writes are not
  ** supported or write level is not applicable.
  const Spec? writeLevelSlot

  ** Point slot for the history address such as "bacnetHis".
  ** This field is null if history syncs are not supported.
  const Spec? hisSlot

  ** Conn slot for the manual poll frequency such as "bacnetPollFreq".
  ** This field is null if manual polling is not supported.
  const Spec? pollFreqSlot

  ** Marker tag name on connector recs such as "modbusConn"
  Str connMarker() { name + "Conn" }

  ** Debug string
  override Str toStr() { "PiConn $name" }

//////////////////////////////////////////////////////////////////////////
// Bind
//////////////////////////////////////////////////////////////////////////

  ** Compute the point diff tags to bind a point to this connector.
  ** The addr is the point's ph.protocols addr slot from its template
  ** spec.  Opts:
  **  - 'conn': Ref of the connector rec (required)
  **  - 'name': Str point name used by register based protocols
  **  - 'cur'/'write'/'his': markers for the deployment modes
  **  - 'writeLevel': Number when applicable to the protocol
  ** Deployment markers are added only when the protocol supports
  ** the mode and an address value resolves.
  virtual Dict bind(Spec addr, Dict opts)
  {
    acc := Str:Obj[:] { ordered = true }
    acc[name + "Point"] = Marker.val
    acc[connRefSlot.name] = opts->conn
    if (opts.has("cur") && curSlot != null)
    {
      val := toCurVal(addr, opts)
      if (val != null) { acc["cur"] = Marker.val; acc[curSlot.name] = val }
    }
    if (opts.has("write") && writeSlot != null)
    {
      val := toWriteVal(addr, opts)
      if (val != null)
      {
        acc["writable"] = Marker.val
        acc[writeSlot.name] = val
        if (writeLevelSlot != null && opts.has("writeLevel")) acc[writeLevelSlot.name] = opts->writeLevel
      }
    }
    if (opts.has("his"))
    {
      acc["his"] = Marker.val
      if (hisSlot != null)
      {
        val := toHisVal(addr, opts)
        if (val != null) acc[hisSlot.name] = val
      }
    }
    return Etc.dictFromMap(acc)
  }

  ** Compute the point diff tags to unbind the given point rec from
  ** this connector.  The cur/writable/his deployment markers are
  ** left in place.
  virtual Dict unbind(Dict rec)
  {
    acc := Str:Obj[:] { ordered = true }
    remove := |Str tag| { if (rec.has(tag)) acc[tag] = None.val }
    remove(name + "Point")
    remove(connRefSlot.name)
    if (curSlot != null)        remove(curSlot.name)
    if (writeSlot != null)      remove(writeSlot.name)
    if (writeLevelSlot != null) remove(writeLevelSlot.name)
    if (hisSlot != null)        remove(hisSlot.name)
    return Etc.dictFromMap(acc)
  }

  ** Point slot value for the current address; default is the addr value
  protected virtual Obj? toCurVal(Spec addr, Dict opts) { slotVal(addr, "addr") }

  ** Point slot value for the write address; default is the addr value
  protected virtual Obj? toWriteVal(Spec addr, Dict opts) { slotVal(addr, "addr") }

  ** Point slot value for the history address; default is the trend value
  protected virtual Obj? toHisVal(Spec addr, Dict opts) { slotVal(addr, "trend") }

  ** Authored addr slot value such as "addr" or "trend"
  protected static Str? slotVal(Spec addr, Str name)
  {
    addr.slot(name, false)?.meta?.get("val")?.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Features
//////////////////////////////////////////////////////////////////////////

  ** Ext 'connFeatures' dict
  const Dict features

  ** Does this connector support learning to walk remote "tree"
  const Bool hasLearn

  ** Does this connector support current value subscription
  const Bool hasCur

  ** Does this connector support writable points
  const Bool hasWrite

  ** Does this connector support history synchronization
  const Bool hasHis

}

**************************************************************************
** PiModbusConn
**************************************************************************

**
** PiModbusConn customizes binding for modbus where point addresses
** reference register map names, never raw addresses.
**
@NoDoc @Js
const class PiModbusConn : PiConn
{
  new make(Namespace ns, Spec ext) : super(ns, ext) {}

  ** Modbus cur references the register map name
  protected override Obj? toCurVal(Spec addr, Dict opts) { opts["name"] }

  ** Modbus write references the register map name and requires
  ** the addr access to allow writes
  protected override Obj? toWriteVal(Spec addr, Dict opts)
  {
    access := slotVal(addr, "access") ?: "r"
    return access.contains("w") ? opts["name"] : null
  }
}
