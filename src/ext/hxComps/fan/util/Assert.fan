//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Checks that `in` stays true.  When `in` turns false, the component logs
** a warning to the `hxComps` log naming itself and `message`, and when
** `in` turns true after a logged warning it logs that at info level.  It
** never throws, and a false `in` does not fault `out`: `out` is the value
** and status of a valid `in`, so it can be linked to an alarm.  An invalid
** `in` is not checked, and `out` holds its value with that status.  This
** is the CDL `Utilities.Assert` block.
**
** A chattering `in` logs a warning at most once an hour, on the
** component's own clock.  While the host clock is behind the latest time
** it has seen, the component executes every cycle.  Falls held back by
** that limit log when the hour passes, even if `in` has recovered.  The
** first execute with a valid `in` of false logs too, as CDL checks the
** assertion at its start time.
**
@Gen
class Assert : HxComp
{
  ** The condition that should stay true
  @Gen virtual StatusBool? in() { get("in") }

  ** Text of the warning logged when `in` turns false
  @Gen virtual Str message { get {get("message")} set {set("message", it)} }

  ** The value and status of `in`, held while `in` is invalid
  @Gen virtual StatusBool? out() { get("out") }

  new make()
  {
  }

  ** Times `in` has turned false, logged or held back
  @NoDoc Int numFailed { private set }

  ** Has the first valid in been seen
  private Bool initialized

  ** Value of in at the last valid execute; true at start, so a first
  ** false is a fall
  private Bool lastIn := true

  ** Was the fall that in is still false from logged
  private Bool fallLogged

  ** Time of the last warning on the component's own clock, the falls
  ** held back since, and the time of the last of them on the host clock
  private Int? lastLog
  private Int unlogged
  private DateTime? lastHeldAt

  ** The component's own clock
  private OwnClock clock := OwnClock()

  ** At most one warning per this long
  private static const Duration logEvery := 1hr

  ** Frequency while no held-back fall is waiting
  private static const Duration idleFreq := 1min

  ** Log name is "hxComps"
  private static const Log log := Log.get("hxComps")

  override Duration? onExecuteFreq()
  {
    // timed comps are collected when mounted, so never return null; run
    // when held-back falls are due even if in does not change
    if (unlogged <= 0 || lastLog == null || !clock.started || clock.behind) return idleFreq
    left := logEvery - Duration(clock.ticks - lastLog)
    return left > 0ns ? left : idleFreq
  }

  override Void onExecute()
  {
    // while the clock is behind, ask for the next cycle (see OwnClock)
    clock.tick(cx.now)
    if (clock.behind) execute
    u := in
    update(cx.now, u)
    flushHeld(u)
  }

  private Void update(DateTime now, StatusBool? u)
  {
    if (u == null) return set("out", null)

    // an invalid in is not checked, so a false under it logs nothing
    if (!u.status.isValid)
    {
      o := out
      if (initialized && o != null) write(o.val, u.status)
      return
    }

    // CDL: assert(u, message, AssertionLevel.warning), once per fall
    v := u.val
    if (!v && lastIn)
    {
      numFailed++
      this.fallLogged = false
      if (windowOpen) warn
      else { unlogged++; lastHeldAt = now }
    }
    else if (v && !lastIn)
    {
      if (fallLogged) log.info("${spec.name} @${id}: assertion holds again: ${text}")
      this.fallLogged = false
    }
    this.initialized = true
    this.lastIn = v
    write(v, u.status)
  }

  ** Once logEvery has passed, log the held-back falls: as a fall if in
  ** is still false from the last of them, else as one line with their
  ** count, so a failure is never hidden behind its recovery
  private Void flushHeld(StatusBool? u)
  {
    if (unlogged <= 0 || !windowOpen) return
    stillFalse := u != null && u.status.isValid && !u.val && !fallLogged
    if (stillFalse)
    {
      unlogged--
      warn
      return
    }
    log.warn("${spec.name} @${id}: assertion failed: ${text} ($unlogged falls not logged since the last line, the last at $lastHeldAt; in is ${state(u)}; logged at most once per $logEvery)")
    logged
  }

  ** What in is now, for the held-back line
  private static Str state(StatusBool? u)
  {
    if (u == null) return "null"
    if (!u.status.isValid) return "$u.status"
    return u.val ? "true" : "false"
  }

  ** Log the warning for the fall in is false from
  private Void warn()
  {
    note := unlogged > 0 ? "; $unlogged falls not logged since the last line" : ""
    log.warn("${spec.name} @${id}: assertion failed: ${text} (logged at most once per $logEvery$note)")
    logged
    this.fallLogged = true
  }

  ** A warning went out now, carrying every held-back fall
  private Void logged()
  {
    this.lastLog = clock.ticks
    this.unlogged = 0
  }

  ** Has logEvery passed since the last warning, on the own clock
  private Bool windowOpen()
  {
    lastLog == null || clock.ticks - lastLog >= logEvery.ticks
  }

  ** The message, or a default when it is empty
  private Str text() { message.isEmpty ? "in is false" : message }

  ** Write out when its value or status changes
  private Void write(Bool v, Status status)
  {
    o := out
    if (o != null && o.val == v && o.status == status) return
    set("out", StatusBool(v, status))
  }
}
