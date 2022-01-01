//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 May 2012  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack
using obs
using hx

**
** Connector library base class
**
abstract const class ConnLib : HxLib, HxConnService
{
  ** Constructor
  new make()
  {
    this.connActorPool = ActorPool
    {
      it.name = "$rt.name-$this.name.capitalize"
      it.maxThreads = rec.effectiveMaxThreads
    }
  }

  ** Settings record
  override ConnSettings rec() { super.rec }

  ** Return this instance as HxConnService implementation.
  ** Overrides must call super.
  override HxService[] services() { [this] }

  ** ConnFwLib instance
  @NoDoc ConnFwLib fw() { fwRef.val }
  private const AtomicRef fwRef := AtomicRef()

  ** Model which defines tags and functions for this connector.
  ** The model is not available until after the library has started.
  @NoDoc ConnModel model() { modelRef.val ?: throw Err("Not avail until after start") }
  private const AtomicRef modelRef := AtomicRef()

//////////////////////////////////////////////////////////////////////////
// Roster
//////////////////////////////////////////////////////////////////////////

  ** List all the connectors
  Conn[] conns() { roster.conns }

  ** Lookup a connector by its record id
  Conn? conn(Ref id, Bool checked := true) { roster.conn(id, checked) }

  ** List all the points across all connectors
  ConnPoint[] points() { roster.points }

  ** Lookup a point by its record id
  ConnPoint? point(Ref id, Bool checked := true) { roster.point(id, checked) }

  ** Roster of connectors and points
  internal const ConnRoster roster := ConnRoster(this)

  ** ConnTuning roster
  @NoDoc ConnTuningRoster tunings() { fw.tunings }

  ** Default tuning to use for this connector
  @NoDoc ConnTuning tuning() { tuningRef.val }
  private const AtomicRef tuningRef := AtomicRef()

//////////////////////////////////////////////////////////////////////////
// Lifecycle
//////////////////////////////////////////////////////////////////////////

  ** Start callback - if overridden you *must* call super
  override Void onStart()
  {
    // must have ConnFwLib installed
    fwRef.val = (ConnFwLib)rt.lib("conn")

    // update library level tuning default
    tuningRef.val = tunings.forLib(this)

    // build def model
    model := ConnModel(this)
    this.modelRef.val = model

    // load roster
    roster.start
  }

  ** Stop callback - if overridden you *must* call super
  override Void onStop()
  {
  }

  ** Record update - if overridden you *must* call super
  override Void onRecUpdate()
  {
    tuningRef.val = tunings.forLib(this)
  }

  ** Connector rec event - route to roster
  internal Void onConnEvent(CommitObservation? e)
  {
    if (e != null) roster.onConnEvent(e)
  }

  ** Point rec event - route to roster
  internal Void onPointEvent(CommitObservation? e)
  {
    if (e != null) roster.onPointEvent(e)
  }

//////////////////////////////////////////////////////////////////////////
// HxConnService
//////////////////////////////////////////////////////////////////////////

  ** Connector marker tag such as "bacnetConn"
  override final Str connTag() { model.connTag }

  ** Connector reference tag such as "bacnetConnRef"
  override final Str connRefTag() { model.connRefTag }

  ** Point marker tag such as "bacnetPoint"
  override final Str pointTag() { model.pointTag }

  ** Does connector support current value subscription
  override final Bool hasCur() { model.hasCur }

  ** Does connector support writable points
  override final Bool hasWrite() { model.hasWrite }

  ** Does connector support history synchronization
  override final Bool hasHis() { model.hasHis }

  ** Point current address tag name such as "bacnetCur"
  override final Str? curTag() { model.curTag }

  ** Point history sync address tag name such as "bacnetHis"
  override final Str? hisTag() { model.hisTag }

  ** Point write address tag name such as "bacnetWrite"
  override final Str? writeTag() { model.writeTag }

  ** Does connector support learn
  override final Bool hasLearn() { model.hasLearn }

  ** Return if given record matches this connector type
  override final Bool isConn(Dict rec) { rec.has(connTag) }

  ** Return if given record is a point under this connector type
  override final Bool isPoint(Dict rec) { rec.has(connRefTag) }

  ** Return debug details for connector
  override final Str connDetails(Dict rec) { throw Err("TODO") }

  ** Return debug details for point
  override final Str pointDetails(Dict rec) { throw Err("TODO") }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal const ActorPool connActorPool
}

**************************************************************************
** ConnSettings
**************************************************************************

**
** ConnSettings is the base class for connector library settings.
**
const class ConnSettings : TypedDict
{
  ** Constructor
  new make(Dict d, |This| f) : super(d) { f(this) }

  ** Default tuning to use when connTuningRef is not explicitly
  ** configured on the connector or point record.
  @TypedTag
  const Ref? connTuningRef

  ** Max threads for the connector's actor pool.  Adding more threads allows
  ** more connectors to work concurrently processing their messages. However
  ** more threads will incur additional memory usage. In general this value
  ** should be somewhere between 50% and 75% of the total number of connectors
  ** in the extension.  A restart is required for a change to take effect.
  @TypedTag { restart=true
    meta= Str<|minVal: 1
               maxVal: 5000|> }
  const Int maxThreads:= 100

  ** Get the effective max threads setting to use taking into
  ** consideration the legacy actorPoolMaxThreads tag
  @NoDoc Int effectiveMaxThreads()
  {
    x := get("actorPoolMaxThreads") as Number
    if (x != null) return x.toInt.clamp(1, 5000)
    return maxThreads.clamp(1, 5000)
  }
}


