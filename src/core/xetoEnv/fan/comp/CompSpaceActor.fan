//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Sep 2024  Brian Frank  Creation
//

using concurrent
using xeto

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

  ** Call the `CompSpace.checkTimers`
  Future checkTimers(DateTime now := DateTime.now(null))
  {
    send(ActorMsg("checkTimers", now))
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

    // dispatch message
    switch (msg.id)
    {
      case "checkTimers": return onCheckTimers(cs, msg.a)
      case "load":        return onLoad(cs, msg.a)
    }

    // route to subclass dispatch
    return onDispatch(msg, cs)
  }

  ** Subclass hook for dispatch
  protected virtual Obj? onDispatch(ActorMsg msg, CompSpace cs)
  {
    throw Err("Unknown msg id: $msg")
  }

  private CompSpaceActorState onInit(Type csType, Obj?[] args)
  {
    CompSpace cs := csType.make(args)
    nsRef.val = cs.ns
    return CompSpaceActorState(cs)
  }

  private This onLoad(CompSpace cs, Str xeto)
  {
    cs.load(xeto)
    return this
  }

  private This onCheckTimers(CompSpace cs, DateTime now)
  {
    cs.checkTimers(now)
    return this
  }

  ** Sync message timeouts
  private static const Duration timeout := 30sec
}

**************************************************************************
** CompSpaceActorState
**************************************************************************

** CompSpaceActorState manages mutable state inside CompSpaceActor
internal class CompSpaceActorState
{
  new make(CompSpace cs) { this.cs = cs }

  CompSpace cs
}

