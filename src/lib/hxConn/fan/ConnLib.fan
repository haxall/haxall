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
using hx

**
** Connector library base class
**
abstract const class ConnLib : HxLib, HxConnService
{
  ** Return this instance as HxConnService implementation.
  ** If overridden you *must* call super.
  override HxService[] services() { [this] }

  ** Model which defines tags and functions for this connector.
  ** The model is not available until after the library has started.
  @NoDoc ConnModel model() { modelRef.val ?: throw Err("Not avail until after start") }
  private const AtomicRef modelRef := AtomicRef()

  ** Start callback - if overridden you *must* call super
  override Void onStart()
  {
    this.modelRef.val = ConnModel(rt.ns, def)
  }

  ** Stop callback - if overridden you *must* call super
  override Void onStop()
  {
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

}


