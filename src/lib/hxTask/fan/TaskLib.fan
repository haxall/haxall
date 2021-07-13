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
using hx

**
** Async task engine library
**
const class TaskLib : HxLib
{
  ** Construction
  new make()
  {
    this.pool = ActorPool { it.name = "${rt.name}-Task"; it.maxThreads = rec.maxThreads }
    this.tasksById = ConcurrentMap()
    this.actor = TaskLibActor(this)
  }

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

  ** Sync until all commits have been reflected in task roster
  Void sync(Duration? timeout := 30sec)
  {
    rt.sync(timeout)
    actor.send(null).get(timeout)
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
        "obsFilter":   "task"
      ]), actor)
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
    tasksById.remove(task.id)
  }

  HxUser user() { userRef.val }
  private const AtomicRef userRef := AtomicRef() // (HxUser.task)

  override Duration? houseKeepingFreq() { 3min }

  override Void onHouseKeeping()
  {
    refreshUser
  }

  internal Void refreshUser()
  {
    user := rt.users.read("task-${rt.name}", false)
    if (user == null) user = rt.users.read("task", false)
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
    rt.users.makeSyntheticUser("task", ["projAccessFilter":"name==${rt.name.toCode}"])
  }

  const ActorPool pool
  const TaskLibActor actor
  private const ConcurrentMap tasksById
}

**************************************************************************
** TaskLibActor
**************************************************************************

const class TaskLibActor : Actor
{
  new make(TaskLib lib) : super(lib.rt.libs.actorPool) { this.lib = lib }
  const TaskLib lib
  override Obj? receive(Obj? msg)
  {
    e := msg as CommitObservation
    if (e != null) lib.onTaskEvent(e)
    return null
  }
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
