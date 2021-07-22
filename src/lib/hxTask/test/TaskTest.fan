//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Apr 2020  Brian Frank  Creation
//

using concurrent
using haystack
using obs
using axon
using folio
using hx

**
** TaskTest
**
class TaskTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Settings
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSettings()
  {
    lib := (TaskLib)rt.libs.add("task")
    verifyEq(lib.rec.typeof.qname, "hxTask::TaskSettings")
    verifyEq(lib.rec.maxThreads, 50)
    verifyEq(lib.rec["maxThreads"], null)

    rt.libs.remove("task")

    lib = (TaskLib)rt.libs.add("task", Etc.makeDict1("maxThreads", n(123)))
    verifyEq(lib.rec.typeof.qname, "hxTask::TaskSettings")
    verifyEq(lib.rec.maxThreads, 123)
    verifyEq(lib.rec->maxThreads, n(123))

    commit(lib.rec, ["maxThreads":n(987)])
    rt.sync
    verifyEq(lib.rec.typeof.qname, "hxTask::TaskSettings")
    verifyEq(lib.rec.maxThreads, 987)
    verifyEq(lib.rec->maxThreads, n(987))

    lib.log.level = LogLevel.err
    commit(lib.rec, ["maxThreads":"bad"])
    rt.sync
    verifyEq(lib.rec.typeof.qname, "hxTask::TaskSettings")
    verifyEq(lib.rec.maxThreads, 50)
    verifyEq(lib.rec->maxThreads,"bad")
  }

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testBasics()
  {
    lib := (TaskLib)rt.libs.add("task")

    func := addFuncRec("topFunc", """(msg) => "top " + msg""")

    // create some tasks
    a    := addTaskRec("A", "topFunc")
    b    := addTaskRec("B", "(msg) => msg.upper")
    c    := addTaskRec("C", "123")
    d    := addTaskRec("D", "(msg) => taskSleep(msg)")
    e    := addTaskRec("E", "(msg) => nowTicks()")
    f    := addTaskRec("F", "(msg) => logErr(\"test\", \"fail if you see this!!!!!\")")
    bad1 := addRec(["dis":"Disabled", "task":m, "taskExpr":"123", "disabled":m])
    bad2 := addRec(["dis":"No taskExpr",  "task":m])
    bad3 := addRec(["dis":"Bas taskExpr", "task":m, "taskExpr":"#"])
    sync

    // verify initial type/status
    aTask := verifyTask(lib.task(a.id), "rec", "idle")
    bTask := verifyTask(lib.task(b.id), "rec", "idle")
    cTask := verifyTask(lib.task(c.id), "rec", "idle")
    dTask := verifyTask(lib.task(d.id), "rec", "idle")
    eTask := verifyTask(lib.task(e.id), "rec", "idle")
    fTask := verifyTask(lib.task(f.id), "rec", "idle")
    bad1Task := verifyTask(lib.task(bad1.id), "disabled", "disabled", "Task is disabled")
    bad2Task := verifyTask(lib.task(bad2.id), "fault",    "fault", "Missing 'taskExpr' tag")
    bad3Task := verifyTask(lib.task(bad3.id), "fault",    "fault", "Invalid expr: axon::SyntaxErr: Unexpected symbol: # (0x23) [taskExpr:1]")

    // verify subscriptions
    verifyEq(rt.isSteadyState, true)
    sched := rt.observables.get("obsSchedule")
    verifyEq(sched.subscriptions.size, 6)
    verifySubscribed(sched, aTask)
    verifySubscribed(sched, bTask)
    verifySubscribed(sched, cTask)
    verifySubscribed(sched, dTask)
    verifySubscribed(sched, eTask)
    verifySubscribed(sched, fTask)

    // change task rec for a
    aOld := lib.task(a.id)
    a = commit(a, ["foo":m])
    sync
    aTask = lib.task(a.id)
    verifyNotSame(aTask, aOld)
    verifyEq(aOld.ticks < aTask.ticks, true)
    verifyKilled(aOld)
    verifyTask(aTask, "rec", "idle")
    verifyUnsubscribed(sched, aOld)
    verifySubscribed(sched, aTask)
    verifyEq(sched.subscriptions.size, 6)

    // verify removing rec f
    verifyEq(fTask.isAlive, true)
    commit(f, null, Diff.remove)
    sync
    verifyEq(lib.task(f.id, false), null)
    verifyKilled(fTask)
    20.times { fTask.send("never") }
    verifyUnsubscribed(sched, fTask)
    verifyEq(sched.subscriptions.size, 5)

    // verify task() func
    verifySame(eval("task($a.id.toCode)"), lib.task(a.id))
    verifySame(eval("task($f.id.toCode, false)"), null)

    // verify taskSend() func
    verifyEq(((Future)eval("""taskSend($a.id.toCode, "hello")""")).get, "top hello")
    verifyEq(((Future)eval("""taskSend($b.id.toCode, "hello")""")).get, "HELLO")
    verifyEq(((Future)eval("""taskSend($c.id.toCode, "hello")""")).get, n(123))

    // taskSendLater
    startTicks := DateTime.nowTicks
    fut := (Future)eval("""taskSendLater($e.id.toCode, 50ms, "ignore")""")
    verifyEq(fut.state.isComplete, false)
    Actor.sleep(100ms)
    verifyEq(fut.state.isComplete, true)
    diff := ((Number)fut.get).toInt - startTicks
    verify(diff > 45ms.ticks)

    // verify taskSendWhenComplete() func (not a very good test)
    verifyEq(eval("""taskSendWhenComplete($b.id.toCode, taskSend($a.id.toCode, "ignore"), "chain").futureGet"""), "CHAIN")

    // futureXxxx
    verifyEq(eval("""taskSend($b.id.toCode, "get").futureGet"""), "GET")
    verifyErr(EvalErr#) { eval("""taskSend($d.id.toCode, 100ms).futureGet(0ms)""") }
    verifyEq(eval("""taskSend($d.id.toCode, 100ms).futureState"""), "pending")
    verifyEq(eval("""taskSend($d.id.toCode, 100ms).futureIsComplete"""), false)
    verifyEq(eval("""taskSend($d.id.toCode, 100ms).futureCancel.futureState"""), "cancelled")
    verifyEq(eval("""taskSend($d.id.toCode, 100ms).futureCancel.futureIsComplete"""), true)

    // stop lib and verify everything is cleaned up
    rt.libs.remove("task")
    rt.sync
    verifyEq(lib.pool.isStopped, true)
    verifyKilled(aTask); verifyUnsubscribed(sched, aTask)
    verifyKilled(bTask); verifyUnsubscribed(sched, bTask)
    verifyKilled(cTask); verifyUnsubscribed(sched, cTask)
    verifyKilled(dTask); verifyUnsubscribed(sched, dTask)
    verifyKilled(eTask); verifyUnsubscribed(sched, eTask)
    verifyKilled(fTask); verifyUnsubscribed(sched, fTask)
    verifyKilled(bad1Task)
    verifyKilled(bad2Task)
    verifyKilled(bad3Task)
    verifyEq(sched.subscriptions.size, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Locals
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testLocals()
  {
    lib := (TaskLib)rt.libs.add("task")

    t := addTaskRec("T",
      """ (msg) => do
            toks: msg.split(" ")
            action: toks[0]
            name: toks[1]
            val: toks[2]
            if (action == "get") return taskLocalGet(name, val)
            if (action == "set") return taskLocalSet(name, val)
            if (action == "remove") return taskLocalRemove(name)
            throw action
          end
          """)

     sync
     //echo(lib.task(t.id).details)

     verifySend(t, "get foo ???", "???")
     verifySend(t, "set foo one", "one")
     verifySend(t, "get foo ???", "one")
     verifySend(t, "remove foo ignore", "one")
     verifySend(t, "get foo ???", "???")
     verifyErr(EvalErr#) { verifySend(t, "set bad-name two", "fail") }
  }

//////////////////////////////////////////////////////////////////////////
// Test Cancel
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testCancel()
  {
    lib := (TaskLib)rt.libs.add("task")

    // setup a task that loops with sleep call
    addFuncRec("testIt",
      """(msg) => do
           100.times(() => do
              taskSleep(100ms)
           end)
         end
         """)
    t := addRec(["dis":"Cancel Test", "task":m, "taskExpr":"testIt"])

    // send kick off message
    Future future := eval("""taskSend($t.id.toCode, "kick it off!")""")

    // cancel the task
    Actor.sleep(50ms)
    eval("taskCancel($t.id.toCode)")

    // block until task raises CancelledErr
    while (!future.state.isComplete)
      Actor.sleep(100ms)

    // verify future ended up in error state with CancelledErr
    verifyEq(future.state, FutureState.err)
    try { future.get; fail }
    catch (EvalErr e) { verifyEq(e.cause.typeof, CancelledErr#) }

    // debug check
    debug := (Str)eval("taskDebugDetails($t.id.toCode)[0]->val")
    verifyEq(debug.contains("sys::CancelledErr"), true)
  }

//////////////////////////////////////////////////////////////////////////
// User
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testUser()
  {
    // this test is only run in SkySpark right now because
    // hxd doesn't support user access filters
    if (!rt.platform.isSkySpark)
    {
      echo("   ##")
      echo("   ## Skip until hxd supports access filters")
      echo("   ##")
      return
    }

    lib := (TaskLib)rt.libs.add("task")

    a := addRec(["dis":"A", "site":m, "foo":m])
    b := addRec(["dis":"B", "site":m])

    t1 := addTaskRec("T1",
      """ (msg) => do
            readAll(site)
          end
          """)
    Ref id1 := t1->id

    t2 := addTaskRec("T2",
      """ (msg) => do
            xq().xqReadAll(site).xqExecute
          end
          """)
    Ref id2 := t2->id

    sync

    ///////////////////////////////////////////////////////
    // synthetic default user
    ///////////////////////////////////////////////////////

    verifySame(lib.user, lib.userFallback)
    verifyEq(lib.user.meta["projAccessFilter"], "name==$rt.name.toCode")

    // synthetic can read both sites
    sites := (Grid)eval("taskSend($id1.toCode, {}).futureWaitFor.futureGet.sortDis")
    verifyEq(sites.size, 2)
    verifyDictEq(sites[0], a)
    verifyDictEq(sites[1], b)

    sites = (Grid)eval("taskSend($id2.toCode, {}).futureWaitFor.futureGet")
    verifyEq(sites.size, 2)

    ///////////////////////////////////////////////////////
    // task user
    ///////////////////////////////////////////////////////

    u := addUser("task", "pass", ["siteAccessFilter":"foo"])
    lib.refreshUser
    verifyEq(lib.user.id, u.id)

    // can read only a
    sites = (Grid)eval("taskSend($id1.toCode, {}).futureWaitFor.futureGet.sortDis")
    verifyEq(sites.size, 1)
    verifyDictEq(sites[0], a)

    // can read a thru xquery
    sites = (Grid)eval("taskSend($id2.toCode, {}).futureWaitFor.futureGet")
    verifyEq(sites.size, 1); verifyDictEq(sites[0], a)

    ///////////////////////////////////////////////////////
    // task-{proj}
    ///////////////////////////////////////////////////////

    u2 := addUser("task-${rt.name}", "pass", ["userRole":"admin"])
    lib.refreshUser
    verifyEq(lib.user.id, u2.id)

    // can read both sites
    sites = (Grid)eval("taskSend($id1.toCode, {}).futureWaitFor.futureGet.sortDis")
    verifyEq(sites.size, 2)
    verifyDictEq(sites[0], a)
    verifyDictEq(sites[1], b)

    // xquery has full access
    if (rt.platform.isSkySpark)
    {
      sites = (Grid)eval("taskSend($id2.toCode, {}).futureWaitFor.futureGet.sortDis")
      verifyEq(sites.size, 2)
      verifyDictEq(sites[0], a)
      verifyDictEq(sites[1], b)
    }

    ///////////////////////////////////////////////////////
    // task-{proj} as su falls back to synthetic
    ///////////////////////////////////////////////////////

    u2 = addUser("task-${rt.name}", "pass", ["userRole":"su"])
    lib.refreshUser
    verifySame(lib.user, lib.userFallback)

    // synthetic can read both sites
    sites = (Grid)eval("taskSend($id1.toCode, {}).futureWaitFor.futureGet.sortDis")
    verifyEq(sites.size, 2)
    verifyDictEq(sites[0], a)
    verifyDictEq(sites[1], b)

    // synthetic xquery access
    sites = (Grid)eval("taskSend($id2.toCode, {}).futureWaitFor.futureGet")
    verifyEq(sites.size, 2)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void sync() { rt.sync }

  Dict addFuncRec(Str name, Str src, Str:Obj? tags := Str:Obj?[:])
  {
    tags["def"] = Symbol("func:$name")
    tags["src"]  = src
    r := addRec(tags)
    rt.sync
    return r
  }

  Dict addTaskRec(Str dis, Str expr)
  {
    addRec(["dis":"Top Func", "task":m, "taskExpr":expr, "obsSchedule":m, "obsScheduleFreq":n(1, "day")])
  }

  Task verifyTask(Task task, Str type, Str status, Str? fault := null)
  {
    lib := (TaskLib)rt.lib("task")
    verifySame(lib.task(task.id), task)
    verifyEq(task.type.name, type)
    verifyEq(task.status.name, status)
    verifyEq(task.fault, fault)
    verifyEq(task.isAlive, fault == null)
    return task
  }

  Void verifyKilled(Task task)
  {
    verifyEq(task.isAlive, false)
    if (task.type != TaskType.disabled && task.type != TaskType.fault)
      verifyEq(task.status, TaskStatus.killed)
    if (task.subscription != null)
      verifyEq(task.subscription.isUnsubscribed, true)
  }

  Void verifySubscribed(Observable o, Task t)
  {
    s := o.subscriptions.find |x| { x.observer === t }
    verifyNotNull(s)
  }

  Void verifyUnsubscribed(Observable o, Task t)
  {
    s := o.subscriptions.find |x| { x.observer === t }
    verifyNull(s)
  }

  Void verifySend(Obj task, Obj msg, Obj expected)
  {
    Ref id := task->id
    msgCode := Etc.toAxon(msg)
    actual := eval("taskSend($id.toCode, $msgCode).futureWaitFor.futureGet")
    // echo("--> $msg | $actual ?= $expected")
    verifyEq(actual, expected)
  }
}