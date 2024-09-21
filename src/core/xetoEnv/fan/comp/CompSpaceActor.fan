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
using haystack::Dict
using haystack::Ref

**
** CompSpaceActor is used to encapsulate a CompSpace and provide
** a thread safe API to execute, observe, and edit the component tree.
** To use:
**   1. Call init with the ComponentSpace type and ctor args
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
  LibNamespace ns() { nsRef.val ?: throw Err("Must call init first") }
  private const AtomicRef nsRef := AtomicRef()

  ** Initialize the CompSpace using given subtype and make args
  ** Future evaluates to this.
  Future init(Type csType, Obj?[] args)
  {
    send(ActorMsg("init", csType, args))
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
  Future execute(DateTime now := DateTime.now(null))
  {
    send(ActorMsg("execute", now))
  }

  ** BlockView feed subscribe; return Grid
  Future feedSubscribe(Str cookie)
  {
    send(ActorMsg("feedSubscribe", cookie))
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
      state = onInit(msg.a, msg.b)
      Actor.locals["csas"] = state
      return this
    }
    cs := state.cs

// TODO: should not need this more than once
Actor.locals[CompSpace.actorKey] = cs

    // dispatch message
    switch (msg.id)
    {
      case "execute":         return onExecute(state, msg.a)
      case "feedPoll":        return onFeedPoll(state, msg.a)
      case "feedSubscribe":   return onFeedSubscribe(state, msg.a)
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

//////////////////////////////////////////////////////////////////////////
// CompSpace Management
//////////////////////////////////////////////////////////////////////////

  private CompSpaceActorState onInit(Type csType, Obj?[] args)
  {
    CompSpace cs := csType.make(args)
    nsRef.val = cs.ns
    state := CompSpaceActorState(cs)
    cs.actorState = state
    return state
  }

  private This onLoad(CompSpace cs, Str xeto)
  {
    cs.load(xeto)
    return this
  }

  private This onExecute(CompSpaceActorState state, DateTime now)
  {
    state.cs.execute(now)
    checkHouseKeeping(state, now)
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

  private Grid onFeedSubscribe(CompSpaceActorState state, Str cookie)
  {
    cs := state.cs

    // create new feed subscription
    feed := CompSpaceFeed(cookie, cs.ver)
    state.feeds.add(cookie, feed)

    // map children of root to dicts
    dicts := Dict[,]
    feedEachChild(cs) |comp|
    {
      dicts.add(CompUtil.compToDict(comp))
    }

    // encode into a grid of brio dicts
    return CompUtil.toFeedGrid(cookie, dicts, null)
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
    feed.lastPollVer = cs.ver
    feed.touch

    // find all the dicts that have been updated since last ver
    dicts := Dict[,]
    feedEachChild(cs) |comp|
    {
      if (comp.spi.ver > lastVer) dicts.add(CompUtil.compToDict(comp))
    }

    // also find all the deleted ids
    deleted := feed.deleted
    feed.deleted = null

    // if nothing has changed return null
    if (dicts.isEmpty && deleted == null) return null

    // return modified comps
    return CompUtil.toFeedGrid(cookie, dicts, deleted)
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
      case "create":    return onFeedCreate(state.cs, req->compSpec, req->x, req->y)
      case "layout":    return onFeedLayout(state.cs, req->id, req->x, req->y, req->w)
      case "link":      return onFeedLink(state.cs, req->fromRef, req->fromSlot, req->toRef, req->toSlot)
      case "unlink":    return onFeedUnlink(state.cs, req->links)
      case "duplicate": return onFeedDuplicate(state.cs, req->ids)
      case "delete":    return onFeedDelete(state.cs, req->ids)
      default:          throw Err("Unknown feedCall: $req")
    }
  }

  private Buf onFeedCreate(CompSpace cs, Ref specRef, Number x, Number y)
  {
    spec := cs.ns.spec(specRef.id)
    comp := cs.createSpec(spec)
    comp.set("compLayout", CompLayout(x.toInt, y.toInt))
    cs.root.add(comp)
    return CompUtil.compToBrio(comp)
  }

  private Obj? onFeedLayout(CompSpace cs, Ref compId, Number x, Number y, Number w)
  {
    comp := cs.readById(compId)
    comp.set("compLayout", CompLayout(x.toInt, y.toInt, w.toInt))
    return null
  }

  private Obj? onFeedLink(CompSpace cs, Ref fromRef, Str fromSlot, Ref toRef, Str toSlot)
  {
    comp := cs.readById(toRef)
    comp.set("links", comp.links.add(toSlot, Etc.link(fromRef, fromSlot)))
    return null
  }

  private Obj? onFeedUnlink(CompSpace cs, Grid links)
  {
    links.each |link|
    {
      comp := cs.readById(link->toRef)
      comp.set("links", comp.links.remove(link->toSlot, Etc.link(link->fromRef, link->fromSlot)))
    }
    return null
  }

  private Obj? onFeedDuplicate(CompSpace cs, Ref[] ids)
  {
    echo("Duplicate comps: $ids")
    throw Err("TODO")
  }

  private Obj? onFeedDelete(CompSpace cs, Ref[] ids)
  {
    ids.each |id|
    {
      comp := cs.readById(id, false)
      if (comp == null) return
      if (comp.parent == null) throw Err("Cannot delete root")
      comp.parent.remove(comp.name)
    }
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
  new make(CompSpace cs) { this.cs = cs }

  ** Component space managed inside actor
  CompSpace cs

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

