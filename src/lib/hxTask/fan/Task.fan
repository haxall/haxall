//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Apr 2020  Brian Frank  COVID-19!
//

using concurrent
using haystack
using obs
using axon
using hx

**
** Task manages running an Axon expression in a background actor
**
const class Task : Actor, Observer, HxTask
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Get the currently running task
  static Task? cur() { Actor.locals["task.cur"] }

  ** Create task for given record
  static new makeRec(TaskLib lib, Dict rec)
  {
    try
    {
      // sanity check
      if (rec.missing("task")) return makeFault(lib, rec, "Missing 'task' tag")

      // disabled
      if (rec.has("disabled")) return makeFault(lib, rec, "Task is disabled", TaskType.disabled)

      // parse taskExpr
      exprVal := rec["taskExpr"]
      if (exprVal == null) return makeFault(lib, rec, "Missing 'taskExpr' tag")
      if (exprVal isnot Str) return makeFault(lib, rec, "Invalid type 'taskExpr' tag, must be Str")
      Expr? expr
      try
        expr = Parser(Loc("taskExpr"), exprVal.toStr.in).parse
      catch (Err e)
        return makeFault(lib, rec, "Invalid expr: $e")

      // valid record task
      return makeOk(lib, rec, expr)
    }
    catch (Err e)
    {
      return makeFault(lib, rec, "Internal error: $e")
    }
  }

  ** Construct for record with valid config
  private new makeOk(TaskLib lib, Dict rec, Expr expr)
    : super.make(lib.pool)
  {
    this.lib  = lib
    this.id   = rec.id
    this.rec  = rec
    this.type = TaskType.rec
    this.expr = expr
  }

  ** Construct for record with faulty config
  private new makeFault(TaskLib lib, Dict rec, Str fault, TaskType type := TaskType.fault)
    : super.make(lib.pool)
  {
    this.lib   = lib
    this.id    = rec.id
    this.rec   = rec
    this.type  = type
    this.fault = fault
    this.expr  = Literal.nullVal
    this.isKilled.val = true
  }

  ** Constructor ephemeral expr called from taskRun
  new makeEphemeral(TaskLib lib, Expr expr)
    : super.make(lib.pool)
  {
    this.lib  = lib
    this.id   = Ref("ephemeral-$ephemeralCounter.getAndIncrement", expr.toStr)
    this.rec  = Etc.emptyDict
    this.type = TaskType.ephemeral
    this.expr = expr
  }
  private static const AtomicInt ephemeralCounter := AtomicInt()

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Parent library
  const TaskLib lib

  ** Unique id - either rec id or ephemeral auto-generated id
  override const Ref id

  ** Task type - fault, disabled, ephemeral, rec
  internal const TaskType type

  ** Error message if type is fault
  internal const Str? fault

  ** Task rec, or empty Dict if ephemeral
  internal const Dict rec

  ** Expression to run asynchronously in task
  internal const Expr expr

//////////////////////////////////////////////////////////////////////////
// Observer
//////////////////////////////////////////////////////////////////////////

  ** Observer meta
  override Dict meta() { Etc.emptyDict }

  ** Actor is self
  override Actor actor() { this }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  override Bool isEmpty() { rec.isEmpty }

  @Operator
  override Obj? get(Str name, Obj? def := null) { rec.get(name, def) }

  override Bool has(Str name) { rec.has(name) }

  override Bool missing(Str name) { rec.missing(name) }

  override Void each(|Obj val, Str name| f) { rec.each(f) }

  override Obj? eachWhile(|Obj val, Str name->Obj?| f) { rec.eachWhile(f) }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    if (name == "dump") return super.trap(name, args)
    return rec.trap(name, args)
  }

//////////////////////////////////////////////////////////////////////////
// Diagnostics
//////////////////////////////////////////////////////////////////////////

  ** Return if task is still alive to process messages
  Bool isAlive() { !isKilled.val }

  ** Raise exception if this task cannot process messages
  internal This checkAlive()
  {
    if (type.isEphemeral) throw TaskEphemeralErr("Cannot send additional messages to ephemeral task: $this")
    if (isAlive) return this
    if (type === TaskType.fault) throw TaskFaultErr("Task is in fault: $this")
    if (type === TaskType.disabled) throw TaskDisabledErr("Task is disabled: $this")
    throw TaskKilledErr("Task is killed: $this")
  }

  ** Set cancel flag to interrupt current evaluation
  internal Void cancel() { isCancelled.val = true }

  ** Set killed flag to prevent further message processing
  internal Void kill() { isKilled.val = true }

  ** Current status
  internal TaskStatus status()
  {
    if (type === TaskType.fault) return TaskStatus.fault
    if (type === TaskType.disabled) return TaskStatus.disabled
    if (isEphemeralDone) return errLast != null ? TaskStatus.doneErr : TaskStatus.doneOk
    if (isKilled.val) return TaskStatus.killed
    return TaskStatus.fromStr(threadState)
  }

  ** Ticks for state change used for efficient feed polling
  internal Int ticks() { ticksRef.val }

  ** Total number of messages processed
  internal Int evalNum() { receiveCount }

  ** Return if this an ephemeral task that has completeed
  internal Bool isEphemeralDone() { type.isEphemeral && evalLastTime > 0 }

  ** Duration ticks of the last time the task was evaluated
  internal Int evalLastTime() { evalLastTimeRef.val }

  ** Total time processing messages
  internal Int evalTotalTicks() { evalTotalTicksRef.val }

  ** Average time processing each message
  internal Int evalAvgTicks() { num := evalNum; return num <= 0 ? 0 : evalTotalTicksRef.val/num }

  ** Number of messages procesed which raised an error
  internal Int errNum() { errNumRef.val }

  ** Last exception raised when processing a message
  internal Err? errLast() { errLastRef.val }

  ** Latest progress dict
  internal Dict progress() { progressRef.val }

  ** Update latest progress dict
  internal This progressUpdate(Dict d)
  {
    progressRef.val = d
    ticksRef.val = Duration.nowTicks
    return this
  }

  ** Return id for string
  override Str toStr()
  {
    s := StrBuf().add("Task @").add(id.toProjRel)
    if (id.disVal != null) s.add(" ").add(id.disVal)
    return s.toStr
  }

  ** Debug details
  internal Str details()
  {
    // dump summary
    buf := StrBuf()
    buf.add("id:           ").add(id.id).add("\n")
    buf.add("dis:          ").add(dis).add("\n")
    buf.add("type:         ").add(type).add("\n")
    buf.add("status:       ").add(status).add("\n")
    buf.add("fault:        ").add(fault).add("\n")
    buf.add("updated:      ").add(Etc.debugDur(ticks)).add("\n")
    buf.add("evalNum:      ").add(evalNum).add("\n")
    buf.add("evalLastTime: ").add(Etc.debugDur(evalLastTime)).add("\n")
    buf.add("evalTotal:    ").add(Duration(evalTotalTicks).toLocale).add("\n")
    buf.add("evalAvg:      ").add(Duration(evalAvgTicks).toLocale).add("\n")
    if (subscriptionErr != null)
      buf.add("subscripton:  ").add(Etc.debugErr(subscriptionErr, "x<")).add("\n")
    else
      buf.add("subscripton:  ").add(subscriptionDebug).add("\n")
    buf.add("errNum:       ").add(errNum).add("\n")
    buf.add("errLast:      ").add(Etc.debugErr(errLast, "x<")).add("\n")
    buf.add("progress:     ").add(progressDebug).add("\n")
    buf.add("\n")
    buf.add("expr:\n").add(Etc.indent(expr.toStr)).add("\n")

    // get built-in Actor dump
    this->dump(buf.out)

    // if running dump thread stack
    threadId := threadIdRef.val
    if (threadId != -1)
    {
      buf.add("\nThread\n")
      trace := HxUtil.threadDump(threadId)
      buf.add(trace)
      while (buf[-1] == '\n') buf.remove(-1)
      buf.add("\n")
    }

    return buf.toStr
  }

  private Str progressDebug()
  {
    p := progress
    str := p.toStr
    if (str.size < 60) return str

    buf := StrBuf().add("\n")
    p.each |v, n|
    {
      buf.add("  ").add(n)
      if (v != Marker.val) buf.add(": ").add(v).add("\n")
    }
    return buf.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Messaging
//////////////////////////////////////////////////////////////////////////

  ** Receive a message
  override Obj? receive(Obj? msg)
  {
    // if we have been killed just drain the msg queue
    if (isKilled.val) throw TaskKilledErr("Task killed")

    // enter running status
    Actor.locals["task.cur"] = this
    start := Duration.nowTicks
    ticksRef.val = start
    threadIdRef.val = HxUtil.threadId

    // evaluate our expression
    Err? err := null
    Obj? result := null
    try
      result = eval(expr, msg)
    catch (Err e)
      err = e

    // exit running status
    end := Duration.nowTicks
    ticksRef.val = end
    evalLastTimeRef.val = end
    evalTotalTicksRef.add(end-start)
    threadIdRef.val = -1

    // re-raise error or return result
    if (err != null)
    {
      errNumRef.increment
      errLastRef.val = err
      throw err
    }

    return result
  }

  private Obj? eval(Expr expr, Obj? msg)
  {
    // reset cancel flag for this evaluation
    isCancelled.val = false

    // create context which checks cancel flag during heartbeat callback
    cx := lib.rt.context.create(lib.user)
    cx.heartbeatFunc = |->|
    {
      if (isCancelled.val || isKilled.val) throw CancelledErr()
    }

    // execute expr within our job context
    Actor.locals[Etc.cxActorLocalsKey] = cx
    try
      return call(expr, cx, msg)
    finally
      Actor.locals.remove(Etc.cxActorLocalsKey)
  }

  private Obj? call(Expr expr, HxContext cx, Obj? msg)
  {
    if (expr.type === ExprType.var) expr = cx.findTop(expr.toStr)
    if (expr is Fn) return ((Fn)expr).call(cx, [msg])
    return expr.eval(cx)
  }

//////////////////////////////////////////////////////////////////////////
// Subscriptions
//////////////////////////////////////////////////////////////////////////

  ** Err raised by subscription
  Err? subscriptionErr() { subscriptionRef.val as Err }

  ** Subscription to observable if applicable
  Subscription? subscription() { subscriptionRef.val as Subscription }

  ** Subscription debug
  internal Str? subscriptionDebug() { subscriptionRef.val?.toStr }

  ** Attempt to subscribe to configured observable
  Void subscribe()
  {
    try
    {
      // only subscribe rec types
      if (!type.isRec) return

      // check if the rec has any of the observeFoo tags
      observable := lib.rt.obs.list.find |o| { rec.has(o.name) }
      if (observable == null) return

      // create subscription using rec itself as the config
      s := observable.subscribe(this, rec)
      subscriptionRef.compareAndSet(null, s)
    }
    catch (Err e) subscriptionRef.val = e
    ticksRef.val = Duration.nowTicks
  }

  ** Unsubscribe from observable if applicable
  internal Void unsubscribe()
  {
    s := subscription
    if (s == null) return
    try
      s.unsubscribe
    catch (Err e)
      lib.log.err("Task.unsubscribe: $dis", e)
  }

//////////////////////////////////////////////////////////////////////////
// Adjunct
//////////////////////////////////////////////////////////////////////////

  ** Get or create the adjunct
  internal HxTaskAdjunct adjunct(|->HxTaskAdjunct| onInit)
  {
    adjunct := adjunctRef.val
    if (adjunct == null) adjunctRef.val = adjunct = onInit()
    return adjunct
  }

  ** Invoke onKill callback for adjunct
  internal Void adjunctOnKill()
  {
    adjunct := adjunctRef.val as HxTaskAdjunct
    if (adjunct == null) return
    try
      adjunct.onKill
    catch (Err e)
      lib.log.err("Task.adjunctOnKill: $dis", e)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const AtomicBool isKilled         := AtomicBool()
  private const AtomicBool isCancelled      := AtomicBool()
  private const AtomicInt ticksRef          := AtomicInt(Duration.nowTicks)
  private const AtomicInt evalLastTimeRef   := AtomicInt()
  private const AtomicInt evalTotalTicksRef := AtomicInt()
  private const AtomicInt threadIdRef       := AtomicInt(-1)
  private const AtomicInt errNumRef         := AtomicInt()
  private const AtomicRef errLastRef        := AtomicRef() // Err
  private const AtomicRef subscriptionRef   := AtomicRef() // Err or Subscription
  private const AtomicRef adjunctRef        := AtomicRef() // HxTaskAdjunct
  private const AtomicRef progressRef       := AtomicRef(Etc.emptyDict) // Dict
}

**************************************************************************
** TaskType
**************************************************************************

internal enum class TaskType
{
  fault,
  disabled,
  rec,
  ephemeral

  Bool isRec() { this === this }

  Bool isEphemeral() { this === ephemeral }
}

**************************************************************************
** TaskStatus
**************************************************************************

internal enum class TaskStatus
{
  fault,
  disabled,
  idle,
  pending,
  running,
  killed,
  doneOk,
  doneErr
}


