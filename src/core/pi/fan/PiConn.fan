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
    byConn := Spec:PiConn[:]
    byName := Str:PiConn[:]
    byAddr := Spec:PiConn[:]

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
            c := PiConn(ns, extSpec)
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

  ** Map addr spec name to conn model name: "ModbusAddr" -> "modbus"
  private static Str addrToName(Spec addr)
  {
    n := addr.name
    if (n.endsWith("Addr")) n = n[0..-5]
    return n.decapitalize
  }

  ** Lookup conn model for a connector spec walking base types
  PiConn? forConn(Spec? spec, Bool checked := true) { lookup(byConn, spec, checked) }

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

  ** Debug string
  override Str toStr() { "PiConn $name" }

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

