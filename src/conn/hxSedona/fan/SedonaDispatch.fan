//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 May 2012  Brian Frank  Creation
//

using haystack
using hx
using hxConn
using [java]java.net
using [java]fanx.interop
using [java]sedona.dasp
using [java]sedona.sox
using [java]sedona.sox::SoxClient$Listener as SoxClientListener
using [java]sedona::Slot as SedonaSlot

**
** SedonaDispatch
**
class SedonaDispatch : ConnDispatch
{
  new make(Obj arg)  : super(arg) {}

//////////////////////////////////////////////////////////////////////////
// Messaging
//////////////////////////////////////////////////////////////////////////

  override Obj? onReceive(HxMsg msg)
  {
    msgId := msg.id
    if (msgId === "updateCur") return onUpdateCur(msg.a)
    if (msgId === "readComp")  return onReadComp(msg.a)
    if (msgId === "soxClosed") return onSoxClosed(msg.a)
    if (msgId === "writeCompProperty")
    {
      onWriteProperty(msg.a, msg.b)
      return null
    }
    return super.onReceive(msg)
  }

//////////////////////////////////////////////////////////////////////////
// Connection
//////////////////////////////////////////////////////////////////////////

  override Void onOpen()
  {
    try
    {
      uriVal := rec["uri"] ?: throw FaultErr("Missing 'uri' tag")
      uri    := uriVal as Uri ?: throw FaultErr("Type of 'uri' must be Uri, not $uriVal.typeof.name")
      uriScheme := uri.scheme ?: ""
      host   := uri.host ?: ""
      port   := uri.port ?: 1876
      user   := rec["username"] ?: ""
      pass   := rt.db.passwords.get(id.toStr) ?: ""

      scheme = SedonaScheme.schemes.find |s| { uriScheme == s.uriScheme }
      if (scheme == null) throw FaultErr("Unsupported scheme: '$uriScheme'")

      dasm = scheme.createDaspSocket(rec)
      sox = SoxClient(dasm, scheme.inetAddress(uri), port.toInt, user, pass)
      sox.addListener(SoxConnListener(conn))
      sox.connect(scheme.options(conn))
    }
    catch (Err e)
    {
      onClose
      throw toConnErr(e)
    }
  }

  private Err toConnErr(Err e)
  {
    daspErr := Interop.toJava(e) as DaspException
    if (daspErr != null)
    {
      if (daspErr.getMessage.startsWith("No response")) return DownErr("No response", e)
      switch (daspErr.errorCode)
      {
        case DaspConst.INCOMPATIBLE_VERSION: return FaultErr("Incompatible Dasp version", e)
        case DaspConst.BUSY:                 return DownErr("Busy", e)
        case DaspConst.DIGEST_NOT_SUPPORTED: return FaultErr("Digest not supported", e)
        case DaspConst.NOT_AUTHENTICATED:    return FaultErr("Not authenticated", e)
        case DaspConst.TIMEOUT:              return DownErr("Timeout", e)
      }
    }
    return e
  }

  override Void onClose()
  {
    sox?.close
    if (dasm != null) scheme.closeDaspSocket(dasm)
    sox = null
    dasm = null
    scheme = null
    points.each |point| { setPointData(point, null) }
  }

  override Dict onPing()
  {
    // read version info, we always expect sys to be first kit
    versionInfo := sox.readVersion
    plat := versionInfo.platformId
    KitVersion[] kits := versionInfo.kits
    version := kits.first.version.toStr

    return Etc.makeDict(["sedonaVersion":version, "sedonaPlatform":plat])
  }

  private Obj? onSoxClosed(Str? cause)
  {
    close(DownErr(cause ?: "lost connection"))
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Reads/Learn
//////////////////////////////////////////////////////////////////////////

  private Dict onReadComp(Number id)
  {
    open
    comp := sox.load(id.toInt)
    mask := SoxComponent.TREE.or(SoxComponent.CONFIG).or(SoxComponent.RUNTIME)
    sox.update(comp, mask)
    return SedonaUtil.compToDict(comp)
  }

  override Grid onLearn(Obj? arg)
  {
    compId := arg as Number
    if (compId == null) compId = Number.zero
    SoxComponent comp := sox.load(compId.toInt)
    SoxComponent[] kids := comp.children

    meta := ["sedonaConnRef":this.id,
             "compId":compId,
             "type":comp.type.qname]
    cols := ["dis", "learn", "type", "kind",
             "sedonaCur", "sedonaWrite", "point"]
    rows := Obj?[,]

    // first row is component itself
    rows.add(learnCompRow(comp, true))

    // slots
    SedonaSlot[] slots := comp.type.slots
    slots.each |slot|
    {
      row := learnSlotRow(comp, slot)
      if (row != null) rows.add(row)
    }

    // children components
    kids.each |kid| { rows.add(learnCompRow(kid, false)) }

    return Etc.makeListsGrid(meta, cols, null, rows)
  }

  private Obj?[]? learnSlotRow(SoxComponent comp, SedonaSlot slot)
  {
    if (slot.name == "meta") return null
    if (slot.isAction) return null

    kind := SedonaUtil.sedonaTypeToKind(slot.type)
    ro := slot.facets.getb("readonly", false)

    Str? addr := null
    if (kind != null) addr = comp.id.toStr + "." + slot.name
    pointMarker := addr != null ? Marker.val : null

    return Obj?[
      slot.name,          // dis
      null,               // learn
      slot.type.name,     // type
      kind,               // kind
      addr,               // sedonaCur
      ro ? null : addr,   // sedonaWrite
      pointMarker,        // point
    ]
  }

  private Obj?[] learnCompRow(SoxComponent comp, Bool self)
  {
    learn := self ? null : Number(comp.id)
    Str? kind := null
    Str? curAddr := null
    Str? writeAddr := null

    out := comp.type.slot("out", false)
    if (out != null)
    {
      kind = SedonaUtil.sedonaTypeToKind(out.type)
      if (kind != null) curAddr = comp.id.toStr + ".out"
    }

    in := comp.type.slot("in", false)
    if (in != null && curAddr != null)
    {
      inKind := SedonaUtil.sedonaTypeToKind(in.type)
      ro := in.facets.getb("readonly", false)
      if (inKind == kind && !ro) writeAddr = comp.id.toStr + ".in"
    }

    pointMarker := curAddr != null ? Marker.val : null

    return [
      comp.name,          // dis
      learn,              // learn
      comp.type.qname,    // type
      kind,               // kind
      curAddr,            // sedonaCur
      writeAddr,          // sedonaWrite
      pointMarker,        // point (filled in later)
    ]
  }

//////////////////////////////////////////////////////////////////////////
// Points
//////////////////////////////////////////////////////////////////////////

  ** Callback for watch, do subscription on comp
  override Void onWatch(ConnPoint[] points)
  {
    points.each |pt|
    {
      try
        syncCurPoint(pt, "sub")
      catch (Err e)
        pt.updateCurErr(e)
    }
  }

  ** Callback for unwatch, do unsubscription on comp
  override Void onUnwatch(ConnPoint[] points)
  {
    comps := SoxComponent[,]
    points.each |pt|
    {
      comp := pointToComp(pt)
      if (comp != null) comps.add(comp)
    }
    sox?.unsubscribe(comps, SoxComponent.CONFIG.or(SoxComponent.RUNTIME))
  }

  ** Callback for sedonaSyncCur, do explicit readProp
  override Void onSyncCur(ConnPoint[] points)
  {
    open
    points.each |point|
    {
      try
        syncCurPoint(point, "read")
      catch (Err e)
        point.updateCurErr(e)
    }
  }

  ** Callback for SoxCompListener, our SoxComp is already updated
  Obj? onUpdateCur(Ref id)
  {
    point := point(id, false)
    if (point != null)
    {
      try
        syncCurPoint(point, "update")
      catch (Err e)
        point.updateCurErr(e)
    }
    return null
  }

  ** Implementation for onWatch, onSyncCur, and onUpdateCur
  private Void syncCurPoint(ConnPoint point, Str mode)
  {
    if (sox == null) throw DownErr("No sox client")

    addr := point.rec["sedonaCur"] ?: throw FaultErr("Missing 'sedonaCur' tag")
    comp := load(point, addr)
    slot := toCompSlot(comp, addr)
    unit := point.unit

    Obj? sval
    if (mode === "update")
    {
      sval = comp.get(slot)
    }
    else if (mode === "sub")
    {
      mask := slot.isConfig ? SoxComponent.CONFIG : SoxComponent.RUNTIME
      sox.subscribe(comp, mask)
      sval = comp.get(slot)
    }
    else if (mode === "read")
    {
      sval = sox.readProp(comp, slot)
    }
    else throw Err("invalid state!")

    fval := SedonaUtil.valueToFan(sval, point.unit)
    point.updateCurOk(fval)
  }

  override Void onWrite(ConnPoint point, ConnWriteInfo info)
  {
    try
    {
      addr := point.rec["sedonaWrite"] ?: throw FaultErr("Missing 'sedonaWrite' tag")
      comp := load(point, addr)
      slot := toCompSlot(comp, addr)
      sval := SedonaUtil.fanToValue(slot.type, info.val)
      sox.write(comp, slot, sval)
      point.updateWriteOk(info)
    }
    catch (Err e)
    {
      point.updateWriteErr(info, e)
    }
  }

  private Void onWriteProperty(Str addr, Obj? val) {
    open
    comp := sox.load(toCompId(addr))
    slot := toCompSlot(comp, addr)
    sval := SedonaUtil.fanToValue(slot.type, val)
    sox.write(comp, slot, sval)
  }

  private SoxComponent load(ConnPoint point, Str addr)
  {
    try
    {
      comp := pointToComp(point)
      if (comp != null && comp.client === sox) return comp
      comp = sox.load(toCompId(addr))
      slot := toCompSlot(comp, addr)
      comp.listener = SoxCompListener(conn, point.id, slot.name)
      setPointData(point, Unsafe(comp))
      return comp
    }
    catch (Err e)
    {
      msg := e.msg
      x := msg.index("Request failed:")
      if (x != null) throw FaultErr(msg[x..-1], e)
      throw e
    }
  }

  ** Given addr "id.slot", get component id part
  private Int toCompId(Str addr)
  {
    try
      return addr[0..<addr.index(".")].toInt
    catch (Err e)
      throw FaultErr("addr must be compId.slot: $addr")
  }

  ** Given addr "id" or "id.slot", get slot part.  If slot
  ** not defined then we assume "out"
  private SedonaSlot toCompSlot(SoxComponent comp, Str addr)
  {
    slotName := addr[addr.index(".")+1..-1]
    return comp.type.slot(slotName, false) ?: throw FaultErr("Unknown slot '${comp.type.qname}.$slotName'")
  }

  private SoxComponent? pointToComp(ConnPoint pt)
  {
    (pt.data as Unsafe)?.val
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  SedonaScheme? scheme
  DaspSocket? dasm
  SoxClient? sox
}

**************************************************************************
** SoxConnListener
**************************************************************************

internal const class SoxConnListener : SoxClientListener
{
  new make(Conn c) { this.conn = c }
  const Conn conn
  override Void soxClientClosed(SoxClient? client)
  {
    conn.send(HxMsg("soxClosed", client.closeCause))
  }
}

**************************************************************************
** SoxCompListener
**************************************************************************

internal const class SoxCompListener : SoxComponentListener
{
  new make(Conn conn, Ref id, Str slot)
  {
    this.conn = conn
    this.pointId = id
    this.slot = slot
  }

  const Conn conn
  const Ref pointId
  const Str slot

  override Void changed(SoxComponent? c, Int mask)
  {
    conn.send(HxMsg("updateCur", pointId))
  }
}