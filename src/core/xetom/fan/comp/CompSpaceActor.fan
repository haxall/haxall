//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Sep 2024  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** CompSpaceActor is used to encapsulate a CompSpace and provide
** a thread safe API to execute, observe, and edit the component tree.
** To use:
**   1. Call init with the ComponentSpace
**   2. Call load with the Xeto string
**   3. Call checkTimers periodically
**
const class CompSpaceActor : Actor
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(ActorPool pool) : super(pool) {}

//////////////////////////////////////////////////////////////////////////
// Api
//////////////////////////////////////////////////////////////////////////

  ** Namespace for the CompSpace - must have called init
  Namespace ns() { nsRef.val ?: throw Err("Must call init first") }
  private const AtomicRef nsRef := AtomicRef()

  ** Initialize the CompSpace; Future evaluates to this.
  Future init(CompSpace cs)
  {
    send(ActorMsg("init", Unsafe(cs)))
  }

  ** Load the CompSpace with the given Xeto string.
  ** Future evaluates to this.
  Future load(Str xeto)
  {
    send(ActorMsg("load", xeto))
  }

  ** Save to Xeto string
  Future save()
  {
    send(ActorMsg("save"))
  }

  ** Call `CompSpace.execute`
  Future execute(Dict opts := Etc.dict0)
  {
    send(ActorMsg("execute", opts))
  }

  ** BlockView feed subscribe; return Grid
  Future feedSubscribe(Str cookie, Dict gridMeta)
  {
    send(ActorMsg("feedSubscribe", cookie, gridMeta))
  }

  ** BlockView feed poll; return Grid or null
  Future feedPoll(Str cookie)
  {
    send(ActorMsg("feedPoll", cookie))
  }

  ** BlockView feed unsubscribe; return null
  Future feedUnsubscribe(Str cookie)
  {
    send(ActorMsg("feedUnsubscribe", cookie))
  }

  ** BlockView feed call; return null
  Future feedCall(Dict req)
  {
    send(ActorMsg("feedCall", req))
  }

//////////////////////////////////////////////////////////////////////////
// Messaging
//////////////////////////////////////////////////////////////////////////

  ** Dispatch message
  override final Obj? receive(Obj? msgObj)
  {
    msg := (ActorMsg)msgObj

    // get or init state
    state := Actor.locals["csas"] as CompSpaceActorState
    if (state == null)
    {
      if (msg.id != "init") throw Err("Must call init first")
      state = onInit(msg.a)
      Actor.locals["csas"] = state
      return this
    }
    cs := state.cs

    // dispatch message
    switch (msg.id)
    {
      case "execute":         return onExecute(state, msg.a)
      case "feedPoll":        return onFeedPoll(state, msg.a)
      case "feedSubscribe":   return onFeedSubscribe(state, msg.a, msg.b)
      case "feedUnsubscribe": return onFeedUnsubscribe(state, msg.a)
      case "feedCall":        return onFeedCall(state, msg.a)
      case "load":            return onLoad(cs, msg.a)
      case "save":            return cs.save
    }

    // route to subclass dispatch
    return onDispatch(msg, cs)
  }

  ** Subclass hook for dispatch
  protected virtual Obj? onDispatch(ActorMsg msg, CompSpace cs)
  {
    throw Err("Unknown msg id: $msg")
  }

  ** Subclass hook to create context for execute
  protected virtual CompContext initExecuteContext(Dict opts)
  {
    MCompContext(opts["now"] as DateTime ?: DateTime.now)
  }

  ** Subclass hook to execute the component space. The CompContext
  ** will already have been installed as an actor local when this is invoked.
  **
  ** The default implementation simply calls 'execute()' on the component space.
  protected virtual Void onExecuteSpace(CompSpace cs)
  {
    cs.execute
  }

//////////////////////////////////////////////////////////////////////////
// CompSpace Management
//////////////////////////////////////////////////////////////////////////

  private CompSpaceActorState onInit(Unsafe unsafe)
  {
    CompSpace cs := unsafe.val
    Actor.locals[CompSpace.actorKey] = cs
    nsRef.val = cs.ns
    state := CompSpaceActorState(cs)
    state.spi.actorState = state
    cs.spi.init(ns.spec("sys.comp::Comp")) // don't really love this
    cs.start
    return state
  }

  private This onLoad(CompSpace cs, Str xeto)
  {
    cs.load(xeto)
    return this
  }

  private This onExecute(CompSpaceActorState state, Dict opts)
  {
    cs      := state.cs
    cx      := initExecuteContext(opts)
    savedCx := Actor.locals[ActorContext.actorLocalsKey]
    Actor.locals[ActorContext.actorLocalsKey] = cx
    try
      onExecuteSpace(cs)
    finally
      Actor.locals[ActorContext.actorLocalsKey] = savedCx
    return this
  }

  private Void checkHouseKeeping(CompSpaceActorState state, DateTime now)
  {
    // run house keeping every 5sec from checkTimers
    if (now.ticks - state.lastHouseKeeping.ticks > 5sec.ticks)
    {
      state.lastHouseKeeping = now
      onHouseKeeping(state)
    }
  }

  private Void onHouseKeeping(CompSpaceActorState state)
  {
    expireFeeds(state)
  }

//////////////////////////////////////////////////////////////////////////
// BlockView Feeds
//////////////////////////////////////////////////////////////////////////

  private Grid onFeedSubscribe(CompSpaceActorState state, Str cookie, Dict gridMeta)
  {
    cs := state.cs

    // create new feed subscription
    feed := CompSpaceFeed(cookie, cs.spi.ver)
    state.feeds.add(cookie, feed)

    // map children of root to dicts
    dicts := Dict[,]
    feedEachChild(cs) |comp|
    {
      dicts.add(CompUtil.toFeedDict(comp))
    }

    // encode into a grid of brio dicts
    return CompUtil.toFeedGrid(gridMeta, cookie, dicts, null)
  }

  private Obj? onFeedUnsubscribe(CompSpaceActorState state, Str cookie)
  {
    state.feeds.remove(cookie)
    return null
  }

  private Grid? onFeedPoll(CompSpaceActorState state, Str cookie)
  {
    cs := state.cs

    // lookup feed
    feed := state.feeds[cookie] ?: throw Err("Unknown feed: $cookie")

    // touch it to renew lease time and update lastPollVer
    lastVer := feed.lastPollVer
    feed.lastPollVer = cs.spi.ver
    feed.touch

    // find all the dicts that have been updated since last ver
    dicts := Dict[,]
    feedEachChild(cs) |comp|
    {
      if (comp.spi.ver > lastVer) dicts.add(CompUtil.toFeedDict(comp))
    }

    // also find all the deleted ids
    deleted := feed.deleted
    feed.deleted = null

    // if nothing has changed return null
    if (dicts.isEmpty && deleted == null) return null

    // return modified comps
    return CompUtil.toFeedGrid(Etc.dict0, cookie, dicts, deleted)
  }

  private Void feedEachChild(CompSpace cs, |Comp| f)
  {
    // iterate the roots as the block view components
    cs.root.eachChild(f)
  }

  private Void expireFeeds(CompSpaceActorState state)
  {
    // short circuit if no feeds
    if (state.feeds.isEmpty) return

    // find all feeds that have not been touched in over 1min
    now := Duration.nowTicks
    Str[]? cookies
    state.feeds.each |feed|
    {
      age := now - feed.touched
      if (age < 1min.ticks) return
      if (cookies == null) cookies = Str[,]
      cookies.add(feed.cookie)
    }

    // unsubscribe the expired cookies
    if (cookies.isEmpty) return
    cookies.each |cookie| { onFeedUnsubscribe(state, cookie) }
  }

  private Obj? onFeedCall(CompSpaceActorState state, Dict req)
  {
    switch (req->type)
    {
      case "create":      return onFeedCreate(state, req->compSpec, req->x, req->y)
      case "layout":      return onFeedLayout(state, req->id, req->x, req->y, req->w)
      case "link":        return onFeedLink(state, req->fromRef, req->fromSlot, req->toRef, req->toSlot)
      case "unlink":      return onFeedUnlink(state, req->links)
      case "duplicate":   return onFeedDuplicate(state, req->ids)
      case "delete":      return onFeedDelete(state, req->ids)
      case "update":      return onFeedUpdate(state, req->id, req->diff)
      case "batchUpdate": return onFeedBatchUpdate(state, req->diffs)
      default:            throw Err("Unknown feedCall: $req")
    }
  }

  private Dict onFeedCreate(CompSpaceActorState s, Ref specRef, Number x, Number y)
  {
    comp := s.edit.create(s.cs.root.id, specRef.id, CompLayout(x.toInt, y.toInt))
    return CompUtil.toFeedDict(comp)
  }

  private Obj? onFeedLayout(CompSpaceActorState s, Ref compId, Number x, Number y, Number w)
  {
    comp := s.edit.layout(compId, CompLayout(x.toInt, y.toInt, w.toInt))
    return null
  }

  private Obj? onFeedLink(CompSpaceActorState s, Ref fromRef, Str fromSlot, Ref toRef, Str toSlot)
  {
    s.edit.link(fromRef, fromSlot, toRef, toSlot)
    return null
  }

  private Obj? onFeedUnlink(CompSpaceActorState s, Grid links)
  {
    links.each |link|
    {
      s.edit.unlink(link->fromRef, link->fromSlot, link->toRef, link->toSlot)
    }
    return null
  }

  private Obj? onFeedDuplicate(CompSpaceActorState s, Ref[] ids)
  {
    comps := s.edit.duplicate(ids)
    return (Dict[])comps.map |comp| { CompUtil.toFeedDict(comp) }
  }

  private Obj? onFeedDelete(CompSpaceActorState s, Ref[] ids)
  {
    ids.each |id| { s.edit.delete(id) }
    return null
  }

  private Obj? onFeedUpdate(CompSpaceActorState s, Ref id, Dict diff)
  {
    s.edit.update(id, diff)
    return null
  }

  private Obj? onFeedBatchUpdate(CompSpaceActorState s, Dict[] diffs)
  {
    diffs.each |diff| { onFeedUpdate(s, diff.id, diff) }
    return null
  }
}

**************************************************************************
** CompSpaceActorState
**************************************************************************

** CompSpaceActorState manages mutable state inside CompSpaceActor
@Js
internal class CompSpaceActorState
{
  ** Constructor
  new make(CompSpace cs) { this.cs = cs; this.spi = cs.spi }

  ** Component space managed inside actor
  CompSpace cs

  ** Service provider interface for cs
  MCompSpaceSpi spi

  ** Convenience for spi.edit
  CompSpaceEdit edit() { spi.edit }

  ** Subscriptions keyed by cookie
  Str:CompSpaceFeed feeds := [:]

  ** Timestamp of last house keeping
  DateTime lastHouseKeeping := DateTime.now

  ** Unmounted
  Void onUnmount(Comp comp)
  {
    // add this id to all the feeds
    feeds.each |feed|
    {
      map := feed.deleted
      if (map == null) feed.deleted = map = Ref:Ref[:]
      map[comp.id] = comp.id
    }
  }
}

**************************************************************************
** CompSpaceFeed
**************************************************************************

** CompSpaceFeed manages one block feed subscription keyed by cookie
@Js
internal class CompSpaceFeed
{
  ** Constructor
  new make(Str cookie, Int lastPollVer)
  {
    this.cookie      = cookie
    this.touchedRef  = AtomicInt(Duration.nowTicks)
    this.lastPollVer = lastPollVer
  }

  ** Cookie which keys the subscription
  const Str cookie

  ** Ticks last time this session was "touched"
  Int touched() { touchedRef.val }
  private const AtomicInt touchedRef

  ** Touch this session to indicate usage
  Void touch() { touchedRef.val = Duration.nowTicks }

  ** CompSpace.ver of last poll
  Int lastPollVer

  ** Deleted component ids
  [Ref:Ref]? deleted

  ** Debug string
  override Str toStr() { "$cookie lastPollVer=$lastPollVer" }
}

**************************************************************************
** MCompContext - simple implementation
**************************************************************************

@NoDoc @Js
class MCompContext : CompContext
{
  new make(DateTime now) { this.now = now }
  const override DateTime now
}

