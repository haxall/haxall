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
** Checks a measured status against its command.  `inMeas` is stable
** once it has kept its value for `debounce`, and counts as stable at the
** first execute.  The check is due while `inMeas` is stable, and
** otherwise once `feedbackDelay` plus `debounce` has passed since the
** last change of `inSet`, or at once if `inSet` has not changed.  While
** the check is due, `lockedFalse` is set when `inSet` is true unless
** `inMeas` is stable and true, and `lockedTrue` when `inSet` is false
** unless `inMeas` is stable and false.  Both are set when `inMeas` stays
** unstable for `feedbackDelay` plus `debounce` from the change that left
** it stable.  An output stays set until `inMeas` is next stable and equal
** to `inSet`, which clears both.  This is the CDL `Logical.Proof` block.
**
** A change of `inMeas` at the instant its `debounce` ends leaves it
** unstable, timed from the change that left it stable.
**
** A change of `inSet` away from a stable `inMeas` sets an output at once,
** so equipment that takes time to prove raises `lockedFalse` on each
** start until its feedback settles.  A `feedbackDelay` below `debounce`
** logs a warning once to the `hxComps` log, and the component computes
** on, as CDL does.  A null input sets both outputs to null, and an
** invalid input holds them, a null included, with the merged status.
** Neither changes the state.  A change of `debounce` or `feedbackDelay`
** starts the component again at the next execute, as at the first.  The
** delays run on the component's own clock, and a delay that ends between
** executes applies in order at the next one.  A step of the clock backward
** counts as no time, but the time between the executes either side of it is
** lost too, up to the size of the step.  While the host clock is behind the
** latest time it has seen, the component executes every cycle.
**
@Gen
class Proof : HxComp
{
  ** Commanded status
  @Gen virtual StatusBool? inSet() { get("inSet") }

  ** Measured status
  @Gen virtual StatusBool? inMeas() { get("inMeas") }

  ** Time `inMeas` must keep its value to be stable
  @Gen virtual Duration debounce { get {get("debounce")} set {set("debounce", it)} }

  ** Time `inMeas` may take to follow `inSet` before `debounce` starts
  @Gen virtual Duration feedbackDelay { get {get("feedbackDelay")} set {set("feedbackDelay", it)} }

  ** True when `inSet` is true but `inMeas` is stuck false
  @Gen virtual StatusBool? lockedFalse() { get("lockedFalse") }

  ** True when `inSet` is false but `inMeas` is stuck true
  @Gen virtual StatusBool? lockedTrue() { get("lockedTrue") }

  new make()
  {
  }

  private Bool initialized

  ** inSet and inMeas at the last valid execute
  private Bool setVal
  private Bool measVal

  ** Clock ticks when inSet last changed, null since the start
  private Int? setAt

  ** Clock ticks when inMeas last changed, null since the start
  private Int? measAt

  ** Clock ticks when inMeas last changed while stable, from which its
  ** unstable time counts
  private Int? unstableAt

  ** The latched values of lockedFalse and lockedTrue
  private Bool locFal
  private Bool locTru

  ** The conditions that set lockedFalse and lockedTrue, and inMeas stable
  ** and equal to inSet, at the last evaluate, so a rise of each is seen
  private Bool preSetFal
  private Bool preSetTru
  private Bool preEqual

  ** The component's own clock at the last valid execute
  private Int? lastEval

  private OwnClock clock := OwnClock()

  ** Whether the delays were short at the last check
  private Bool warned

  ** Frequency while no delay is running
  private static const Duration idleFreq := 1min

  private static const Log log := Log.get("hxComps")

  override Void onChange(CompChangeEvent e)
  {
    // an edit of a delay starts the component again at the next execute
    if (e.name == "debounce" || e.name == "feedbackDelay") this.initialized = false
  }

  override Duration? onExecuteFreq()
  {
    // never null, since timed comps are collected when mounted.  While
    // the clock is behind, onExecute asks for every cycle itself.
    if (!initialized || lastEval == null || !clock.started || clock.behind) return idleFreq
    left := untilNextEnd(lastEval)
    if (left == null) return idleFreq
    left -= clock.ticks - lastEval
    return left > 0 ? Duration(left) : idleFreq
  }

  override Void onExecute()
  {
    // while the clock is behind the latest time seen, ask for every cycle
    clock.tick(cx.now)
    if (clock.behind) execute

    // a null input sets both outputs to null and keeps the state
    s := inSet
    m := inMeas
    if (s == null || m == null)
    {
      set("lockedFalse", null)
      set("lockedTrue", null)
      return
    }

    // an invalid input holds the state and both outputs, null included
    status := s.status.merge(m.status)
    if (!status.isValid)
    {
      lf := lockedFalse
      lt := lockedTrue
      if (initialized && lf != null && lt != null) write(lf.val, lt.val, status)
      return
    }

    t := clock.ticks
    checkDelays

    if (!initialized)
    {
      // the first execute: both inputs count as stable, no delay is
      // running, and the latches and their last inputs start false
      this.initialized = true
      this.setVal = s.val
      this.measVal = m.val
      this.setAt = null
      this.measAt = null
      this.unstableAt = null
      this.locFal = false
      this.locTru = false
      this.preSetFal = false
      this.preSetTru = false
      this.preEqual = false
      evaluate(t)
    }
    else
    {
      // apply the delays that ended since the last execute, in order.  A
      // delay that ends at t is judged after the inputs change at t.
      cur := lastEval
      while (true)
      {
        left := untilNextEnd(cur)
        if (left == null || left >= t - cur) break
        cur += left
        evaluate(cur)
      }

      // a change of inMeas restarts its debounce, and starts its unstable
      // time if inMeas was stable.  A change at the instant its debounce
      // ends leaves it unstable, so the unstable time runs on.
      if (m.val != measVal)
      {
        if (measAt == null || t - measAt > debounce.ticks) this.unstableAt = t
        this.measAt = t
        this.measVal = m.val
      }

      // a change of inSet restarts the wait before the check is due
      if (s.val != setVal)
      {
        this.setAt = t
        this.setVal = s.val
      }
      evaluate(t)
    }
    this.lastEval = t
    write(locFal, locTru, status)
  }

  ** Evaluate the block at clock ticks t with the inputs held
  private Void evaluate(Int t)
  {
    // inMeas is stable once it has kept its value for debounce
    stable := measAt == null || t - measAt >= debounce.ticks
    valTru := measVal && stable
    valFal := !measVal && stable

    // inMeas has stayed unstable for both delays
    total := feedbackDelay.ticks + debounce.ticks
    unstable := !stable && t - unstableAt >= total

    // the check is due while inMeas is stable, while inSet has not changed,
    // and once both delays have passed since inSet last changed
    check := setAt == null || t - setAt >= total || stable

    // the conditions that set lockedFalse and lockedTrue
    setFal := unstable || (check && setVal && !valTru)
    setTru := unstable || (check && !setVal && !valFal)

    // inMeas stable and equal to inSet, whose rise clears both outputs
    equal := setVal ? valTru : valFal
    clear := equal && !preEqual

    // a clear wins.  Otherwise the rise of a condition sets its output.
    if (clear)
    {
      this.locFal = false
      this.locTru = false
    }
    else
    {
      if (setFal && !preSetFal) this.locFal = true
      if (setTru && !preSetTru) this.locTru = true
    }
    this.preSetFal = setFal
    this.preSetTru = setTru
    this.preEqual = equal
  }

  ** Ticks from a to the next end of a delay, or null if none is
  ** running.  Only differences are formed, so a far end cannot overflow.
  private Int? untilNextEnd(Int a)
  {
    total := feedbackDelay.ticks + debounce.ticks
    Int? best := null
    best = sooner(best, a, measAt, debounce.ticks)
    best = sooner(best, a, unstableAt, total)
    best = sooner(best, a, setAt, total)
    return best
  }

  ** The sooner of best and the time from a to at + d, if that is after a
  private static Int? sooner(Int? best, Int a, Int? at, Int d)
  {
    if (at == null) return best
    left := d - (a - at)
    if (left <= 0) return best
    return best == null || left < best ? left : best
  }

  ** Warn once each time feedbackDelay drops below debounce, as CDL does
  private Void checkDelays()
  {
    short := feedbackDelay < debounce
    if (short && !warned)
      log.warn("${spec.name} @${id}: feedbackDelay ${feedbackDelay} is less than debounce ${debounce}; CDL requires feedbackDelay >= debounce and computes on")
    this.warned = short
  }

  ** Write both outputs when a value or status changes
  private Void write(Bool f, Bool t, Status status)
  {
    of := lockedFalse
    if (of == null || of.val != f || of.status != status) set("lockedFalse", StatusBool(f, status))
    ot := lockedTrue
    if (ot == null || ot.val != t || ot.status != status) set("lockedTrue", StatusBool(t, status))
  }
}
