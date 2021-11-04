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
** Async task engine library
**
const class TaskLib : HxLib, HxTaskService
{
  ** Construction
  new make()
  {
    this.pool = ActorPool { it.name = "${rt.name}-Task"; it.maxThreads = rec.maxThreads }
    this.tasksById = ConcurrentMap()
  }

  ** Publish HxTaskService
  override HxService[] services() { [this] }

  ** Settings record
  override TaskSettings rec() { super.rec }

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

  ** Run the given expression asynchronously in an ephemeral task.
  ** Return a future to track the asynchronous result.
  override Future run(Expr expr, Obj? msg := null)
  {
    Task.makeEphemeral(this, expr).send(msg)
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
  internal Void onTaskEvent(CommitObservation? e)
  {
    // null is sync message
    if (e == null) return

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

  ** Kill a task off and unmount it from the registry
  internal Void kill(Task task)
  {
    task.kill
    task.unsubscribe
    task.adjunctOnKill
    tasksById.remove(task.id)
  }

  HxUser user() { userRef.val }
  private const AtomicRef userRef := AtomicRef()

  override Duration? houseKeepingFreq() { 3min }

  override Void onHouseKeeping()
  {
    refreshUser
  }

  internal Void refreshUser()
  {
    user := rt.user.read("task-${rt.name}", false)
    if (user == null) user = rt.user.read("task", false)
    if (user == null) user = userFallback
    if (user.isSu)
    {
      log.err("Task user must not be su")
      user = userFallback
    }
    userRef.val = user
  }

  once HxUser userFallback()
  {
    rt.user.makeSyntheticUser("task", ["projAccessFilter":"name==${rt.name.toCode}"])
  }

  const ActorPool pool
  private const ConcurrentMap tasksById
}

**************************************************************************
** TaskSettings
**************************************************************************

const class TaskSettings : TypedDict
{
  ** Constructor
  new make(Dict d, |This| f) : super(d) { f(this) }

  ** Max threads for the task actor pool
  @TypedTag { restart=true }
  const Int maxThreads:= 50

}

