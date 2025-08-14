//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Apr 2020  Brian Frank  COVID-19!
//

using concurrent
using xeto
using haystack
using obs
using axon
using hx

**
** Async task engine library
**
const class TaskExt : ExtObj, ITaskExt
{
  ** Construction
  new make()
  {
    this.pool = ActorPool { it.name = "${rt.name}-Task"; it.maxThreads = settings.maxThreads }
    this.tasksById = ConcurrentMap()
  }

  ** Settings record
  override TaskSettings settings() { super.settings }

  ** Lookup a task by its id
  internal Task? task(Ref id, Bool checked := true)
  {
    task := tasksById.get(id)
    if (task != null) return task
    if (checked) throw UnknownTaskErr("Task not found: $id.toCode")
    return null
  }

  ** List the current tasks
  internal Task[] tasks() { tasksById.vals(Task#) }

  ** Get the currently running task
  override HxTask? cur(Bool checked := true)
  {
    t := Task.cur
    if (t != null) return t
    if (checked) throw NotTaskContextErr("Not running in task context")
    return null
  }

  ** Run the given expression asynchronously in an ephemeral task.
  ** Return a future to track the asynchronous result.
  override Future run(Expr expr, Obj? msg := null)
  {
    spawnEphemeral(expr).send(msg)
  }

  ** Update current task's progress info for debugging.  If not
  ** running in the context of a task, then this is a no op.
  override Void progress(Dict progress)
  {
    Task.cur?.progressUpdate(progress)
  }

  ** Get or create an adjunct within the context of the current
  ** task.  If an adjunct is already attached to the task then return
  ** it, otherwise invoke the given function to create it.  Raise an
  ** exception if not running with the context of a task.
  override HxTaskAdjunct adjunct(|->HxTaskAdjunct| onInit)
  {
    task := Task.cur ?: throw NotTaskContextErr("Not running in task context")
    return task.adjunct(onInit)
  }

  ** Start callback
  override Void onStart()
  {
    refreshUser

    observe("obsCommits",
      Etc.makeDict([
        "obsAdds":      Marker.val,
        "obsUpdates":   Marker.val,
        "obsRemoves":   Marker.val,
        "obsAddOnInit": Marker.val,
        "syncable":     Marker.val,
        "obsFilter":   "task"
      ]), #onTaskEvent)
  }

  ** Subscribe tasks on steady state
  override Void onSteadyState()
  {
    tasks.each |task| { task.subscribe }
  }

  ** Stop callback
  override Void onStop()
  {
    tasks.each |t| { kill(t) }
    pool.kill
  }

  ** Event when 'task' records are modified
  internal Void onTaskEvent(CommitObservation e)
  {
    // on update or remove, then kill existing task
    if (e.isUpdated || e.isRemoved)
    {
      oldTask := task(e.id, false)
      if (oldTask != null) kill(oldTask)
    }

    // on add or update, then spawn off new task
    if (e.isAdded || e.isUpdated)
    {
      newTask := Task.makeRec(this, e.newRec)
      spawn(newTask)
    }
  }

  ** Kill and re-spawn given task
  internal Task restart(Task task)
  {
    if (!task.type.isRec) throw Err("Cannot restart non-rec task: $task")
    kill(task)
    return spawn(Task.makeRec(this, task.rec))
  }

  ** Spawn new task and mount it registry
  private Task spawn(Task task)
  {
    tasksById.add(task.id, task)
    if (rt.isSteadyState) task.subscribe
    return task
  }

  ** Spawn ephemeral task with short linger for debugging
  internal Task spawnEphemeral(Expr expr)
  {
    task := Task.makeEphemeral(this, expr)
    tasksById.add(task.id, task)
    return task
  }

  ** Kill a task off and unmount it from the registry
  internal Void kill(Task task)
  {
    task.kill
    task.unsubscribe
    task.adjunctOnKill
    tasksById.remove(task.id)
  }

  User user() { userRef.val }
  private const AtomicRef userRef := AtomicRef()

  override Duration? houseKeepingFreq() { 17sec }

  override Void onHouseKeeping()
  {
    refreshUser
    cleanupEphemerals
  }

  internal Void refreshUser()
  {
    user := sys.user.read("task-${rt.name}", false)
    if (user == null) user = sys.user.read("task", false)
    if (user == null) user = userFallback
    if (user.isSu)
    {
      log.err("Task user must not be su")
      user = userFallback
    }
    userRef.val = user
  }

  once User userFallback()
  {
    sys.user.makeUser("task", ["projAccessFilter":"name==${rt.name.toCode}"])
  }

  private Void cleanupEphemerals()
  {
    now := Duration.nowTicks
    linger := settings.ephemeralLinger.ticks
    tasks.each |task|
    {
      if (task.isEphemeralDone && now - task.evalLastTime > linger)
        kill(task)
    }
  }

  const ActorPool pool
  private const ConcurrentMap tasksById
}

**************************************************************************
** TaskSettings
**************************************************************************

const class TaskSettings : Settings
{
  ** Constructor
  new make(Dict d, |This| f) : super(d) { f(this) }

  ** Max threads for the task actor pool
  @Setting { restart=true }
  const Int maxThreads:= 50

  ** Linger time for an ephemeral task before it is removed from debug
  @Setting
  const Duration ephemeralLinger := 10min

}

