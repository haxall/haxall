//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2026  Lincoln Harmer  Creation
//

using concurrent
using xeto
using haystack

class ProofTest : HxCompTest
{
  static const DateTime T := DateTime.fromJava(1_760_486_400_000, TimeZone.utc)

  ** The check is due at once while inMeas is stable, waits for both delays
  ** while it is not, and an inMeas unstable for both delays sets both
  Void testTransitions()
  {
    Proof c := createComp("Proof")
    verifyEq(c.debounce, 10sec)
    verifyEq(c.feedbackDelay, 1min)
    c.debounce = 1sec
    c.feedbackDelay = 2sec
    sim(c, T) |cx|
    {
      // debounce 1s and feedbackDelay 2s, so both delays are 3s

      // 0s: at the first execute inMeas is stable and equal to inSet
      c.set("inSet", sb(false)); c.set("inMeas", sb(false))
      cx.step(T); verifyOuts(c, false, false)

      // 10s: inSet rises away from a stable false inMeas, so the check is
      // due at once and sets lockedFalse
      c.set("inSet", sb(true))
      cx.step(T + 10sec); verifyOuts(c, true, false)

      // 11s: inMeas follows, but changed just now, so it is not stable
      c.set("inMeas", sb(true))
      cx.step(T + 11sec); verifyOuts(c, true, false)

      // 12s: inMeas has kept true for 1s, stable and equal, so both clear
      cx.step(T + 12sec); verifyOuts(c, false, false)

      // 20s: inSet falls away from a stable true inMeas: lockedTrue
      c.set("inSet", sb(false))
      cx.step(T + 20sec); verifyOuts(c, false, true)

      // 21s: inMeas follows and is not stable; 22s: stable, both clear
      c.set("inMeas", sb(false))
      cx.step(T + 21sec); verifyOuts(c, false, true)
      cx.step(T + 22sec); verifyOuts(c, false, false)

      // 30s: both rise.  inMeas changed just now, so it is not stable, and
      // the check waits 3s from the change of inSet, to 33s
      c.set("inSet", sb(true)); c.set("inMeas", sb(true))
      cx.step(T + 30sec); verifyOuts(c, false, false)

      // 32.5s: inMeas, stable true since 31s, falls.  The check is not due
      // before 33s
      c.set("inMeas", sb(false))
      cx.step(T + 32.5sec); verifyOuts(c, false, false)
      cx.step(T + 32.999sec); verifyOuts(c, false, false)

      // 33s: the check is due, inSet is true and inMeas is not stable and
      // true, so lockedFalse is set
      cx.step(T + 33sec); verifyOuts(c, true, false)

      // 40s: inMeas rises and is not stable; 41s: stable, both clear
      c.set("inMeas", sb(true))
      cx.step(T + 40sec); verifyOuts(c, true, false)
      cx.step(T + 41sec); verifyOuts(c, false, false)

      // 50s: inMeas leaves stable.  inSet last changed at 30s, so the check
      // is due and sets lockedFalse
      c.set("inMeas", sb(false))
      cx.step(T + 50sec); verifyOuts(c, true, false)

      // 50.5s to 52.5s: inMeas flips each 0.5s and never keeps a value for
      // 1s, so it stays unstable from 50s
      [true, false, true, false, true].each |v, i|
      {
        c.set("inMeas", sb(v))
        cx.step(T + 50.5sec + Duration(i * 500ms.ticks)); verifyOuts(c, true, false)
      }

      // 53s: unstable for 3s from 50s, so both are set
      cx.step(T + 53sec); verifyOuts(c, true, true)

      // 53.5s: inMeas has kept true for 1s since 52.5s, so both clear
      cx.step(T + 53.5sec); verifyOuts(c, false, false)
    }
  }

  ** An instability wholly between two executes still latches lockedTrue
  Void testDelaysBetweenExecutes()
  {
    // debounce 1s and feedbackDelay 0.5s, so both delays are 1.5s
    c := newProof(1sec, 500ms)
    sim(c, T) |cx|
    {
      c.set("inSet", sb(false)); c.set("inMeas", sb(false))
      cx.step(T)
      // 10s: inMeas leaves stable and inSet changes, so the check waits
      c.set("inSet", sb(true)); c.set("inMeas", sb(true))
      cx.step(T + 10sec)
      // 10.6s: inMeas changes within 1s and stays unstable from 10s
      c.set("inMeas", sb(false))
      cx.step(T + 10.6sec)
      verifyOuts(c, false, false, Status.ok)
      // 11.5s: unstable for 1.5s from 10s sets both.  At 11.6s inMeas is
      // stable false, not equal to inSet, so nothing clears.  The execute
      // at 12s applies both in order.
      cx.step(T + 12sec)
      verifyOuts(c, true, true, Status.ok)
    }
  }

  ** A change of inMeas at the instant its debounce ends leaves it
  ** unstable, timed from the change that left it stable
  Void testChangeAtDebounceEnd()
  {
    c := newProof(1sec, 2sec)
    sim(c, T) |cx|
    {
      c.set("inSet", sb(true)); c.set("inMeas", sb(true))
      cx.step(T); verifyOuts(c, false, false)
      // 10s: inMeas leaves stable.  inSet has not changed, so the check is
      // due and sets lockedFalse
      c.set("inMeas", sb(false))
      cx.step(T + 10sec); verifyOuts(c, true, false)
      // 11s, 12s, 13s: each change comes as the 1s debounce ends, so inMeas
      // stays unstable from 10s, and at 13s, 3s on, both are set
      [true, false, true].each |v, i|
      {
        c.set("inMeas", sb(v))
        cx.step(T + 11sec + Duration(i * 1sec.ticks)); verifyOuts(c, true, i == 2, Status.ok, i)
      }
    }
  }

  ** A null input sets both outputs to null, and an invalid input holds
  ** them, a null included, with the merged status.  Neither changes the
  ** state.
  Void testNullAndInvalid()
  {
    c := newProof(1sec, 2sec)
    sim(c, T) |cx|
    {
      // 0s: inSet true away from a stable false inMeas: lockedFalse
      c.set("inSet", sb(true)); c.set("inMeas", sb(false))
      cx.step(T); verifyOuts(c, true, false)

      // 1s: both invalid, so the outputs hold with the merged status
      c.set("inSet", sb(true, Status.down))
      c.set("inMeas", sb(false, Status.fault))
      cx.step(T + 1sec); verifyOuts(c, true, false, Status.down.merge(Status.fault))

      // 2s: a null sets both null; 3s: an invalid input holds the null
      c.set("inMeas", null)
      cx.step(T + 2sec)
      verifyNull(c.lockedFalse)
      verifyNull(c.lockedTrue)
      c.set("inMeas", sb(false, Status.fault))
      cx.step(T + 3sec)
      verifyNull(c.lockedFalse)

      // 4s: valid again, on the state of 0s.  lockedFalse is still set,
      // and inMeas changed from false just now, so it is not stable
      c.set("inMeas", sb(true))
      c.set("inSet", sb(true))
      cx.step(T + 4sec); verifyOuts(c, true, false)

      // 5s: inMeas has kept true for 1s, stable and equal, so both clear
      cx.step(T + 5sec); verifyOuts(c, false, false)
    }
  }

  ** A feedbackDelay below debounce warns once, and the component computes on
  Void testWarnShortFeedbackDelay()
  {
    c := newProof(1sec, 500ms)
    recs := capture |->|
    {
      sim(c, T) |cx|
      {
        c.set("inSet", sb(true)); c.set("inMeas", sb(true))
        cx.step(T); verifyOuts(c, false, false)
        // 1s: inMeas leaves stable.  inSet has not changed, so the check
        // is due and sets lockedFalse
        c.set("inMeas", sb(false))
        cx.step(T + 1sec); verifyOuts(c, true, false)
      }
    }
    verifyEq(recs.size, 1)
    verifyEq(recs.first.level, LogLevel.warn)
  }

  ** An edit of debounce or feedbackDelay starts the component again
  Void testEditStartsAgain()
  {
    c := newProof(500ms, 750ms)
    sim(c, T) |cx|
    {
      c.set("inSet", sb(true)); c.set("inMeas", sb(true))
      cx.step(T); verifyOuts(c, false, false)
      // 1s: inMeas leaves stable.  inSet has not changed, so the check is
      // due and sets lockedFalse
      c.set("inMeas", sb(false))
      cx.step(T + 1sec); verifyOuts(c, true, false)
      // 1.2s: inMeas changes back within 0.5s, still not stable
      c.set("inMeas", sb(true))
      cx.step(T + 1.2sec); verifyOuts(c, true, false)
      // 1.3s: the edit starts again as at the first execute, where inMeas
      // counts as stable and is equal to inSet, so both clear
      c.debounce = 2sec
      cx.step(T + 1.3sec); verifyOuts(c, false, false)
      // 1.4s: inMeas leaves stable with inSet unchanged since the start
      // again, so the check is due and sets lockedFalse
      c.set("inMeas", sb(false))
      cx.step(T + 1.4sec); verifyOuts(c, true, false)
    }
  }

  ** While the clock is behind the latest time seen, a delay ends on time
  Void testClockBackOwnExecute()
  {
    c := newProof(500ms, 750ms)
    sim(c, T) |cx|
    {
      c.set("inSet", sb(true)); c.set("inMeas", sb(true))
      cx.step(T); verifyOuts(c, false, false)
      // 10s: inMeas leaves stable and the check is due: lockedFalse
      c.set("inMeas", sb(false))
      cx.step(T + 10sec); verifyOuts(c, true, false)
      cx.step(T + 10.2sec); verifyOuts(c, true, false)
      // the host clock steps back an hour, which counts as no time.  inMeas
      // rises within 0.5s of its fall, so it is not stable.
      back := T + 10.2sec - 1hr
      c.set("inMeas", sb(true))
      cx.step(back)
      verifyOuts(c, true, false)
      // the clock is behind, so each step executes.  inMeas is stable 0.5s
      // after it rose, at k = 5, and equal to inSet, so both clear.
      (1..10).each |k|
      {
        cx.step(back + Duration(k * 100ms.ticks))
        verifyOuts(c, k < 5, false, Status.ok, k)
      }
    }
  }

  private Proof newProof(Duration debounce, Duration feedbackDelay)
  {
    c := (Proof)createComp("Proof")
    c.debounce = debounce
    c.feedbackDelay = feedbackDelay
    return c
  }

  private Void sim(Comp c, DateTime ts, |SimulatedCompContext| f)
  {
    SimulatedCompContext(cs, ts).asCur |cx|
    {
      cs.root.add(c)
      f(cx)
      cs.root.remove(c.name)
    }
  }

  private Void verifyOuts(Proof c, Bool f, Bool t, Status status := Status.ok, Obj? at := null)
  {
    verifyNotNull(c.lockedFalse, "lockedFalse at $at")
    verifyNotNull(c.lockedTrue, "lockedTrue at $at")
    verifyEq(c.lockedFalse.val, f, "lockedFalse at $at")
    verifyEq(c.lockedTrue.val, t, "lockedTrue at $at")
    verifyEq(c.lockedFalse.status, status, "status at $at")
    verifyEq(c.lockedTrue.status, status, "status at $at")
  }

  private LogRec[] capture(|->| f)
  {
    acc := LogRec[,]
    Actor.locals["hxComps.proofTest"] = acc
    handler := |LogRec r| { if (r.logName == "hxComps" && r.msg.startsWith("Proof")) (Actor.locals["hxComps.proofTest"] as LogRec[])?.add(r) }
    Log.addHandler(handler)
    try f()
    finally { Log.removeHandler(handler); Actor.locals.remove("hxComps.proofTest") }
    return acc
  }
}
