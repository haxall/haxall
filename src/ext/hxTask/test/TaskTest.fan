//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Apr 2020  Brian Frank  Creation
//

using concurrent
using xeto
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

  @HxTestProj
  Void testSettings()
  {
    ext := (TaskExt)addExt("hx.task")
    verifyEq(ext.settings.typeof.qname, "hxTask::TaskSettings")
    verifyEq(ext.settings.maxThreads, 50)
    verifyEq(ext.settings["maxThreads"], null)

    proj.libs.remove("hx.task")

    ext = (TaskExt)proj.exts.add("hx.task", Etc.dict1("maxThreads", n(123)))
    verifyEq(ext.settings.typeof.qname, "hxTask::TaskSettings")
    verifyEq(ext.settings.maxThreads, 123)
    verifyEq(ext.settings->maxThreads, n(123))

    ext.settingsUpdate(["maxThreads":n(987)])
    proj.sync
    verifyEq(ext.settings.typeof.qname, "hxTask::TaskSettings")
    verifyEq(ext.settings.maxThreads, 987)
    verifyEq(ext.settings->maxThreads, n(987))

    ext.log.level = LogLevel.err
    ext.settingsUpdate(["maxThreads":"bad"])
    proj.sync
    verifyEq(ext.settings.typeof.qname, "hxTask::TaskSettings")
    verifyEq(ext.settings.maxThreads, 50)
    verifyEq(ext.settings->maxThreads,"bad")
  }

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testBasics()
  {
    ext := (TaskExt)addExt("hx.task")
    sync
    ext.spi.sync

    addFunc("topFunc", """(msg) => "top " + msg""")

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
    aTask := verifyTask(ext.task(a.id), "rec", "idle")
    bTask := verifyTask(ext.task(b.id), "rec", "idle")
    cTask := verifyTask(ext.task(c.id), "rec", "idle")
    dTask := verifyTask(ext.task(d.id), "rec", "idle")
    eTask := verifyTask(ext.task(e.id), "rec", "idle")
    fTask := verifyTask(ext.task(f.id), "rec", "idle")
    bad1Task := verifyTask(ext.task(bad1.id), "disabled", "disabled", "Task is disabled")
    bad2Task := verifyTask(ext.task(bad2.id), "fault",    "fault", "Missing 'taskExpr' tag")
    bad3Task := verifyTask(ext.task(bad3.id), "fault",    "fault", "Invalid expr: axon::SyntaxErr: Unexpected symbol: # (0x23) [taskExpr:1]")

    // verify subscriptions
    forceSteadyState
    verifyEq(proj.isSteadyState, true)
    sync
    sched := proj.obs.get("obsSchedule")
    verifyEq(sched.subscriptions.size, 6)
    verifySubscribed(sched, aTask)
    verifySubscribed(sched, bTask)
    verifySubscribed(sched, cTask)
    verifySubscribed(sched, dTask)
    verifySubscribed(sched, eTask)
    verifySubscribed(sched, fTask)

    // change task rec for a
    aOld := ext.task(a.id)
    a = commit(a, ["foo":m])
    sync
    aTask = ext.task(a.id)
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
    verifyEq(ext.task(f.id, false), null)
    verifyKilled(fTask)
    20.times { fTask.send("never") }
    verifyUnsubscribed(sched, fTask)
    verifyEq(sched.subscriptions.size, 5)

    // verify task() func
    verifySame(eval("task($a.id.toCode)"), ext.task(a.id))
    verifySame(eval("task($f.id.toCode, false)"), null)

    // verify taskSend() func
    verifyEq(((Future)eval("""taskSend($a.id.toCode, "hello")""")).get, "top hello")
    verifyEq(((Future)eval("""taskSend($b.id.toCode, "hello")""")).get, "HELLO")
    verifyEq(((Future)eval("""taskSend($c.id.toCode, "hello")""")).get, n(123))

    // taskSendLater
    startTicks := DateTime.nowTicks
    fut := (Future)eval("""taskSendLater($e.id.toCode, 50ms, "ignore")""")
    verifyEq(fut.status.isComplete, false)
    Actor.sleep(100ms)
    verifyEq(fut.status.isComplete, true)
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

    // taskRun
    verifyEq(eval("""taskRun(x=>x, "test").futureGet"""), "test")
    verifyDictEq(eval("""taskRun(x=>x, {foo}).futureGet"""), ["foo":m])

    // test service
    verifyEq(proj.exts.task.run(Parser(Loc.eval, "(msg)=>msg+100".in).parse, n(7)).get, n(107))
    verifyEq(proj.exts.task.cur(false), null)
    verifyErr(NotTaskContextErr#) { proj.exts.task.cur(true) }

    // stop lib and verify everything is cleaned up
    proj.libs.remove("hx.task")
    proj.sync
    verifyEq(ext.pool.isStopped, true)
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

    // test service
    verifyErr(UnknownExtErr#) { proj.exts.task }
  }

//////////////////////////////////////////////////////////////////////////
// Locals
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testLocals()
  {
    ext := (TaskExt)addExt("hx.task")

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
     //echo(ext.task(t.id).details)

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

  @HxTestProj
  Void testCancel()
  {
    ext := (TaskExt)addExt("hx.task")

    // setup a task that loops with sleep call
    addFunc("testIt",
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
    while (!future.status.isComplete)
      Actor.sleep(100ms)

    // verify future ended up in error state with CancelledErr
    verifyEq(future.status, FutureStatus.err)
    try { future.get; fail }
    catch (EvalErr e) { verifyEq(e.cause.typeof, CancelledErr#) }

    // debug check
    debug := (Str)eval("taskDebugDetails($t.id.toCode)[0]->val")
    verifyEq(debug.contains("sys::CancelledErr"), true)
  }

//////////////////////////////////////////////////////////////////////////
// Adjuncts
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testAdjuncts()
  {
    ext := (TaskExt)addExt("hx.task")

    t := addTaskRec("T1",
      """ (msg) => do
            taskTestAdjunct()
          end
          """)

    // verify adjunct initialization
    verifyEq(eval("taskSend($t.id.toCode, null).futureGet"), n(1))
    TestTaskAdjunct a := ext.task(t.id).adjunct |->HxTaskAdjunct| { throw Err() }
    verifyEq(a.counter.val, 1)
    verifyEq(a.onKillFlag.val, false)

    // verify adjunct is reused on subsequent calls to task
    verifyEq(eval("taskSend($t.id.toCode, null).futureGet"), n(2))
    verifyEq(eval("taskSend($t.id.toCode, null).futureGet"), n(3))
    verifySame(a, ext.task(t.id).adjunct |->HxTaskAdjunct| { throw Err() })
    verifyEq(a.counter.val, 3)
    verifyEq(a.onKillFlag.val, false)

    // make a change to the task to force restart
    commit(t, ["foo":m])
    sync
    verifyEq(eval("taskSend($t.id.toCode, null).futureGet"), n(1))
    verifyNotSame(a, ext.task(t.id).adjunct |->HxTaskAdjunct| { throw Err() })
    verifyEq(a.counter.val, 3)
    verifyEq(a.onKillFlag.val, true)
  }

//////////////////////////////////////////////////////////////////////////
// User
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testUser()
  {
    // this test is only run in SkySpark right now because
    // hxd doesn't support user access filters
    if (!sys.info.type.isSkySpark)
    {
      echo("   ##")
      echo("   ## Skip until hxd supports access filters")
      echo("   ##")
      return
    }

    ext := (TaskExt)addExt("hx.task")

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

    verifySame(ext.user, ext.userFallback)
    verifyEq(ext.user.meta["projAccessFilter"], "name==$proj.name.toCode")

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
    ext.refreshUser
    verifyEq(ext.user.id, u.id)

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

    u2 := addUser("task-${proj.name}", "pass", ["userRole":"admin"])
    ext.refreshUser
    verifyEq(ext.user.id, u2.id)

    // can read both sites
    sites = (Grid)eval("taskSend($id1.toCode, {}).futureWaitFor.futureGet.sortDis")
    verifyEq(sites.size, 2)
    verifyDictEq(sites[0], a)
    verifyDictEq(sites[1], b)

    // xquery has full access
    if (sys.info.type.isSkySpark)
    {
      sites = (Grid)eval("taskSend($id2.toCode, {}).futureWaitFor.futureGet.sortDis")
      verifyEq(sites.size, 2)
      verifyDictEq(sites[0], a)
      verifyDictEq(sites[1], b)
    }

    ///////////////////////////////////////////////////////
    // task-{proj} as su falls back to synthetic
    ///////////////////////////////////////////////////////

    u2 = addUser("task-${proj.name}", "pass", ["userRole":"su"])
    ext.refreshUser
    verifySame(ext.user, ext.userFallback)

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

  Void sync() { proj.sync }

  Dict addTaskRec(Str dis, Str expr)
  {
    addRec(["dis":"Top Func", "task":m, "taskExpr":expr, "obsSchedule":m, "obsScheduleFreq":n(1, "day")])
  }

  Task verifyTask(Task task, Str type, Str status, Str? fault := null)
  {
    ext := (TaskExt)proj.ext("hx.task")
    verifySame(ext.task(task.id), task)
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

