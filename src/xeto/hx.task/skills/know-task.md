# Know Task

The task engine runs Axon asynchronously on background threads.
Each task rec is an actor with its own message queue; you send it
messages and get back futures. Tasks subscribe to observables to
react to schedules, database commits, and point events.

# Task Recs

```trio
task
dis: "My Worker"
taskExpr: "myTaskFunc"
```

- `task`: marker
- `taskExpr`: the message handler - a top-level func name
  (`"myTaskFunc"`), a lambda (`"(msg) => msg.upper"`), or a bare
  expression that ignores the message (`"doWork()"`)
- `disabled`: marker to pause the task

A named func receives the message as its single parameter. Config
errors (missing/invalid taskExpr) put the task in "fault" status.

# Messaging and Futures

```axon
taskSend(task, msg)                     // enqueue now
taskSendLater(task, 30sec, msg)         // enqueue after delay
taskSendWhenComplete(task, future)      // chain: send when future completes
```

All three return a Future. Messages and return values must be
immutable. Future API:

```axon
f.futureGet             // block for result (throws task's error)
f.futureGet(10sec)      // block with timeout (TimeoutErr)
f.futureState           // "pending", "ok", "err", "cancelled"
f.futureIsComplete      // in a terminal state?
f.futureCancel          // dequeue if not yet processing (no guarantee)
f.futureWaitFor         // block until complete, returns the future
futureWaitForAll(fs)    // block on a list
```

`taskSendWhenComplete` with no msg passes the completed future as
the message - chain stages by piping one task's future to the next.

# Subscriptions

A task subscribes to exactly one observable by adding its marker to
the task rec. Subscriptions activate only after the project reaches
steady state.

Scheduled task:

```trio
task
obsSchedule
obsScheduleFreq: 1hr
taskExpr: "readAll(haystackHis).connSyncHis(null)"
```

Schedule config: exactly one of `obsScheduleFreq` (min 1sec) or
`obsScheduleTimes` (list of times of day), optionally filtered by
`obsScheduleDaysOfWeek: "mon,wed,fri"`, `obsScheduleDaysOfMonth`
(negative counts from end), or `obsScheduleSpan`. Schedule events
are skipped while the task's queue is non-empty, so a slow task
never builds a backlog.

Commit-triggered task:

```trio
task
obsCommits
obsAdds
obsUpdates
obsFilter: "equip and hvac"
taskExpr: "onEquipChange"
```

The message is a dict: `{type, ts, subType:"added|updated|removed",
id, oldRec, newRec, user}`. Use `obsAddOnInit` to fire adds for all
existing matches at subscribe time. Transient commits do not fire;
trashing a rec fires as a remove.

Other observables: `obsWatches` (recs entering/leaving watch),
`obsCurVals` (transient curVal commits), `obsHisWrites` (history
writes), `obsPointWrites` (priority array changes).

# Task State

Per-task state persists across messages via task locals:

```axon
(msg) => do
  lastCheck: taskLocalGet("lastCheck", now() - 5min)
  process(lastCheck..now())
  taskLocalSet("lastCheck", now())
end
```

Locals only work inside the task's own context and are cleared on
restart.

# Lifecycle and Errors

- **Any edit to the task rec restarts it**: the actor is killed,
  pending messages are discarded, locals and stats reset
- A message that throws does NOT kill the task; the error goes to
  that message's future and the task keeps processing (`errNum`
  counts them)
- `taskRestart(task)`: manual restart
- `taskCancel(task)`: sets a flag raised as CancelledErr at the
  next Axon heartbeat - it cannot interrupt blocking calls, so
  always use timeouts on network/IO operations

# Ephemeral Tasks

Run a one-off expression in the background:

```axon
taskRun(ioReadCsv(`io/big-import.csv`))       // fire and forget
taskRun((msg) => process(msg), data).futureGet
```

The expression cannot see the calling scope's variables - pass data
through the msg parameter. Ephemeral tasks run once and linger only
for debugging.

# Security

Tasks evaluate as the `task-{proj}` or `task` user; if neither
exists a synthetic user is used, restricted to the local project.
The task user may never have the su role. Grant it permissions like
any other user.

# Monitoring

```axon
tasks()                    // grid of all tasks with status/stats
task(id)                   // lookup one task
taskProgress({step:"..."}) // publish progress dict (from inside task)
taskBalance(tasks)         // least-busy task from a worker pool
taskDebugDetails(task)     // detailed debug report
taskDebugPool()            // actor pool + task user debug
```

Status values: fault, disabled, idle, pending, running, killed,
doneOk/doneErr (ephemeral). Watch `queuePeak` and `evalAvgDur` to
spot backlogs.

# Style Notes

- Keep message handlers short; the thread pool (default 50) is
  shared and blocking calls hold a thread
- Put nontrivial logic in a named func and reference it from
  taskExpr rather than inlining large expressions
- Remember rec edits wipe queue, locals, and stats
- Long-running blocking work (connSyncHis, big IO) belongs in a
  task, with timeouts on every blocking call
