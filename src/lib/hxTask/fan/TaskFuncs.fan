//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Apr 2020  Brian Frank  COVID-19!
//

using concurrent
using haystack
using axon
using hx

**
** Task module Axon functions
**
const class TaskFuncs
{

//////////////////////////////////////////////////////////////////////////
// Task Management
//////////////////////////////////////////////////////////////////////////

  ** Lookup a task by id which is any value supported by `toRecId()`.
  @Axon { admin = true }
  static Task? task(Obj? id, Bool checked := true)
  {
    if (id is Task) return (Task)id
    return lib(curContext).task(Etc.toId(id), checked)
  }

  ** List the current tasks as a grid.
  ** The format of this grid is subject to change.
  @Axon { admin = true }
  static Grid tasks(Dict? opts := null)
  {
    if (opts == null) opts = Etc.emptyDict
    cx := curContext
    lib := lib(cx)
    meta := Str:Obj?[:]
    if (cx.feedIsEnabled) cx.feedAdd(TasksFeed(lib), meta)
    grid := tasksGrid(lib, meta, 0)
    grid = grid.sortDis
    search := opts["search"]?.toStr?.trimToNull
    if (search != null) grid = grid.filter(Filter.search(search), cx)
    return grid
  }

  internal static Grid tasksGrid(TaskLib lib, Obj? meta, Int ticks)
  {
    gb := GridBuilder()
    gb.setMeta(meta)
    gb.addCol("id")
      .addCol("type")
      .addCol("taskStatus")
      .addCol("subscription")
      .addCol("progress")
      .addCol("errNum")
      .addCol("queueSize")
      .addCol("queuePeak")
      .addCol("evalNum")
      .addCol("evalTotalTime")
      .addCol("evalAvglTime")
      .addCol("evalLastTime")
      .addCol("fault")
    lib.tasks.each |t|
    {
      if (t.ticks < ticks) return
      gb.addRow([
        t.id,
        t.type.name,
        t.status.name,
        t.subscriptionDebug,
        t.progress,
        Number(t.errNum),
        Number(t.queueSize),
        Number(t.queuePeak),
        Number(t.evalNum),
        Number.makeDuration(Duration(t.evalTotalTicks)),
        Number.makeDuration(Duration(t.evalAvgTicks)),
        t.evalNum == 0 ? null : DateTime.now(null) - Duration(Duration.nowTicks - t.evalLastTime),
        t.fault
      ])
    }
    return gb.toGrid
  }

  ** Is the current context running asynchrounsly inside a task
  @Axon { admin = true }
  static Bool taskIsRunning()
  {
    Task.cur != null
  }

  ** Return current task if running within the context of an asynchronous
  ** task.  If context is not within a task, then return null or raise
  ** an exception based on checked flag.
  @Axon { admin = true }
  static Task? taskCur(Bool checked := true)
  {
    task := Task.cur
    if (task != null) return task
    if (checked) throw NotTaskContextErr("Not running in task context")
    return null
  }

  ** Run the given expression asynchronously in an ephemeral task.
  ** Return a future to track the asynchronous result.  Note the
  ** expr passed cannot use any variables from the current scope.
  ** See `lib-task::doc#ephemeralTasks`.
  @Axon { admin = true }
  static Future taskRun(Expr expr, Expr msg := Literal.nullVal)
  {
    cx := curContext
    return lib(cx).run(expr, msg.eval(cx))
  }

  ** Restart a task.  This kills the tasks and discards any
  ** pending messages in its queue.  See `lib-task::doc#lifecycle`.
  @Axon { admin = true }
  static Task taskRestart(Obj task)
  {
    lib(curContext).restart(toTask(task))
  }

  **
  ** Set cancel flag for the given task.  Cancelling a task sets an
  ** internal flag which is checked by the context's heartbeat on every
  ** Axon call.  On the next Axon call the current message context
  ** will raise a `sys::CancelledErr` which will be raised by the respective
  ** future.  Cancelling a task does **not** interrupt any current operations,
  ** so any blocking future or I/O calls should always use a timeout.
  **
  @Axon { admin = true }
  static Void taskCancel(Obj task)
  {
    toTask(task).cancel
  }

  **
  ** Update the current running task's progress data with given dict.
  ** This is a silent no-op if the current context is not running in a task.
  **
  ** Example:
  **    // report progress percentage processing a list of records
  **    recs.each((rec, index)=>do
  **      taskProgress({percent: round(100%*index/recs.size), cur:rec.dis})
  **      processRec(rec)
  **    end)
  **    taskProgress({percent:100%})
  **
  @Axon { admin = true }
  static Obj? taskProgress(Obj? progress)
  {
    taskCur(false)?.progressUpdate(Etc.makeDict(progress))
  }

  **
  ** Given a list of one or more tasks, return the next task to use
  ** to perform load balanced work.  The current algorithm returns
  ** the task with the lowest number of messages in its queue.
  **
  @NoDoc @Axon { admin = true }
  static Task taskBalance(Obj tasks)
  {
    lib(curContext).pool.balance(toTasks(tasks))
  }

//////////////////////////////////////////////////////////////////////////
// Messaging
//////////////////////////////////////////////////////////////////////////

  ** Asynchronously send a message to the given task for processing.
  ** Return a future to track the asynchronous result.
  ** See `lib-task::doc#messaging`.
  @Axon { admin = true }
  static Future taskSend(Obj task, Obj? msg)
  {
    toTask(task).checkAlive.send(msg)
  }

  ** Schedule a message for delivery after the specified period of
  ** duration has elapsed.  Once the period has elapsed the message is
  ** appended to the end of the task's queue.  Return a future to
  ** track the asynchronous result.  See `lib-task::doc#messaging`.
  @Axon { admin = true }
  static Future taskSendLater(Obj task, Number dur, Obj? msg)
  {
    toTask(task).checkAlive.sendLater(dur.toDuration, msg)
  }

  ** Schedule a message for delivery after the given future has completed.
  ** Completion may be due to the future returning a result, throwing an
  ** exception, or cancellation.  Return a future to track the asynchronous
  ** result.  See `lib-task::doc#messaging`.
  @Axon { admin = true }
  static Future taskSendWhenComplete(Obj task, Future future, Obj? msg := future)
  {
    toTask(task).checkAlive.sendWhenComplete(future, msg)
  }

//////////////////////////////////////////////////////////////////////////
// Task Locals
//////////////////////////////////////////////////////////////////////////

  ** Get a task local variable by name or def if not defined.
  ** Must be running in a task context.  See `lib-task::doc#locals`.
  @Axon { admin = true }
  static Obj? taskLocalGet(Str name, Obj? def := null)
  {
    checkTaskIsRunning
    return Actor.locals.get(name, def)
  }

  ** Set a task local variable. The name must be a valid tag name. Must
  ** be running in a task context.  See `lib-task::doc#locals`.
  @Axon { admin = true }
  static Obj? taskLocalSet(Str name, Obj? val)
  {
    checkTaskIsRunning
    if (!Etc.isTagName(name)) throw Err("Task local name not valid tag name: $name")
    Actor.locals[name] = val
    return val
  }

  ** Remove a task local variable by name. Must be running in a task
  ** context.  See `lib-task::doc#locals`.
  @Axon { admin = true }
  static Obj? taskLocalRemove(Str name)
  {
    checkTaskIsRunning
    return Actor.locals.remove(name)
  }

//////////////////////////////////////////////////////////////////////////
// Futures
//////////////////////////////////////////////////////////////////////////

  ** Block current thread until a future's result is ready.  A null
  ** timeout will block forever.  If an exception was raised by the
  ** asynchronous computation, then it is raised to the caller.
  ** See `lib-task::doc#futures`.
  @Axon { admin = true }
  static Obj? futureGet(Future future, Number? timeout := null)
  {
    future.get(timeout?.toDuration)
  }

  ** Cancel a future.  If the message is still queued then its
  ** removed from the actor's queue and will not be processed.
  ** No guarantee is made that the message will not be processed.
  ** See `lib-task::doc#futures`.
  @Axon { admin = true }
  static Obj? futureCancel(Future future)
  {
    future.cancel
    return future
  }

  ** Return current state of a future as one of the following strings:
  **  - 'pending': still queued or being processed
  **  - 'ok': completed with result value
  **  - 'err': completed with an exception
  **  - 'cancelled': future was cancelled before processing
  ** See `lib-task::doc#futures`.
  @Axon { admin = true }
  static Str futureState(Future future)
  {
    future.status.name
  }

  ** Return if a future has completed or is still pending a result.
  ** A future is completed by any of the following conditions:
  **   - the task processes the message and returns a result
  **   - the task processes the message and raises an exception
  **   - the future is cancelled
  ** See `lib-task::doc#futures`.
  @Axon { admin = true }
  static Bool futureIsComplete(Future future)
  {
    future.status.isComplete
  }

  ** Block until a future transitions to a completed state (ok,
  ** err, or canceled).  If timeout is null then block forever,
  ** otherwise raise a TimeoutErr if timeout elapses.  Return future.
  ** See `lib-task::doc#futures`.
  @Axon { admin = true }
  static Future futureWaitFor(Future future, Number? timeout := null)
  {
    future.waitFor(timeout?.toDuration)
  }

  ** Block on a list of futures until they all transition to a completed
  ** state.  If timeout is null block forever, otherwise raise TimeoutErr
  ** if any one of the futures does not complete before the timeout elapses.
  ** See `lib-task::doc#futures`.
  @Axon { admin = true }
  static Future[] futureWaitForAll(Future[] futures, Number? timeout := null)
  {
    Future.waitForAll(futures, timeout?.toDuration)
    return futures
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Sleep for the given duration.  If not currently running in
  ** a task this is a no-op.  This will block the current task's thread
  ** and prevent other tasks from using it until the sleep completes.
  ** So this function should be used sparingly and with care.
  @Axon { admin = true }
  static Void taskSleep(Number dur)
  {
    if (taskIsRunning) Actor.sleep(dur.toDuration)
    return dur
  }

  ** Implementation for taskSendAction Axon wrapper
  @NoDoc @Axon { admin = true }
  static Obj? taskDoSendAction(Obj taskIds, Str msg)
  {
    msgDict := TrioReader(msg.in).readDict(false) ?: Etc.emptyDict
    tasks := (Task[])Etc.toIds(taskIds).map |id->Task| { toTask(id) }
    futures := (Future[])tasks.map |task| { taskSend(task, msgDict) }
    return "Sent to $tasks.size tasks"
  }

  ** Return plaintext grid for task's debug details
  @NoDoc @Axon { admin = true }
  static Grid taskDebugDetails(Obj task)
  {
    Etc.makeMapGrid(["view":"text"], ["val":toTask(task).details])
  }

  ** Return plaintext grid for pool debug
  @NoDoc @Axon { admin = true }
  static Grid taskDebugPool()
  {
    lib := lib(curContext)

    buf := StrBuf()

    user := lib.user
    buf.add("User:\n")
    names := Etc.dictNames(user.meta).dup.sort
    names.moveTo("dis", 0).moveTo("username", 0).moveTo("id", 0).moveTo("mod", -1)
    names.each |n|
    {
      buf.add("  ").add(n).add(": ").add(Etc.valToDis(user.meta[n])).add("\n")
    }
    buf.add("\n")

    lib.pool->dump(buf.out)
    return Etc.makeMapGrid(["view":"text"], ["val":buf.toStr])
  }

  ** Refresh the user account used for tasks
  @Axon { admin = true }
  static Void taskRefreshUser()
  {
    lib(curContext).refreshUser
  }

  ** White-box testing for adjunct
  @NoDoc @Axon
  static Number taskTestAdjunct()
  {
    TestTaskAdjunct a := curContext.rt.task.adjunct |->TestTaskAdjunct| { TestTaskAdjunct() }
    a.counter.increment
    return Number(a.counter.val)
  }

  ** Verify running in a task context
  private static Void checkTaskIsRunning()
  {
    if (!taskIsRunning) throw Err("Not running in task context")
  }

  ** Axon coercion to a Task instance
  private static Task toTask(Obj t) { task(t, true) }

  ** Axon coercion to a Task[]
  private static Task[] toTasks(Obj t)
  {
    if (t is List) return ((List)t).map |x->Task| { toTask(x) }
    return Task[toTask(t)]
  }

  ** Current context
  private static HxContext curContext() { HxContext.curHx }

  ** Lookup TaskLib for context
  private static TaskLib lib(HxContext cx) { cx.rt.lib("task") }
}

**************************************************************************
** TestTaskAdjunct (whitebox testing)
**************************************************************************

internal const class TestTaskAdjunct : HxTaskAdjunct
{
  override Void onKill() { onKillFlag.val = true }
  const AtomicBool onKillFlag := AtomicBool()
  const AtomicInt counter := AtomicInt()
}

**************************************************************************
** TasksFeed
**************************************************************************

@NoDoc const class TasksFeed : HxFeed
{
  new make(TaskLib lib) { this.lib = lib }
  const TaskLib lib
  const AtomicInt lastPollTicks := AtomicInt(Duration.nowTicks)
  override Grid onPoll()
  {
    // poll for tasks which have ver updated since last poll ticks
    grid := TaskFuncs.tasksGrid(lib, null, lastPollTicks.val)
    lastPollTicks.val = Duration.nowTicks
    return grid
  }
}

