//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** The base spec for components that sample `in` when `trigger` turns
** from false to true.  The rise is read on execute, so the sample is
** `in` on that cycle.  The first valid execute sets `out` by the
** component's initial equation and is not a rise.  A `trigger` that is
** true on consecutive executes is one rise, so a `SampleTrigger` with a
** period of one cycle or less gives no sample after the first execute.
**
** A null input sets `out` to null and keeps the state.  An invalid input
** holds the state and `out`, and `out` carries the input statuses merged.
** A NaN `in` with a valid status holds `out` and adds fault to the status.
** A rise while `in` is null, invalid or NaN takes no sample.  A rise is
** judged against the last valid value of `trigger`.  The state is not
** persisted.
**
@Gen
abstract class TriggeredComp : HxComp
{
  ** Input to sample
  @Gen virtual StatusNumber? in() { get("in") }

  ** Samples `in` when it turns from false to true
  @Gen virtual StatusBool? trigger { get {get("trigger")} set {set("trigger", it)} }

  ** Output
  @Gen virtual StatusNumber? out() { get("out") }

  private Bool initialized

  ** Last valid value of trigger
  private Bool lastTrigger

  ** Did a parameter fault interrupt the state
  private Bool faulted

  override Void onExecute()
  {
    u := in
    t := trigger

    // CDL when trigger; recorded whatever in is, so a rise while in is
    // not valid is lost
    rose := false
    if (initialized && t != null && t.status.isValid)
    {
      rose = t.val && !lastTrigger
      this.lastTrigger = t.val
    }

    if (u == null || t == null) return set("out", null)

    // a parameter fault is checked before the invalid rule
    status := u.status.merge(t.status)
    if (paramFault)
    {
      if (initialized) this.faulted = true
      return write(held(u), status.set(Status.fault))
    }

    // an invalid input holds out; before the first value, what a fault wrote
    if (!status.isValid)
    {
      o := out
      if (o != null) write(initialized ? heldVal : o.num, status)
      return
    }

    if (u.num.isNaN) return write(held(u), status.set(Status.fault))

    // a changed or fixed parameter starts again from the initial equations
    if (initialized && (faulted || restartNeeded)) this.initialized = false

    if (!initialized)
    {
      // CDL: no when fires at initialization, so a true trigger is not a rise
      this.initialized = true
      this.faulted = false
      this.lastTrigger = t.val
      init(u)
    }
    else if (rose)
    {
      sample(u)
    }
    write(outVal, outStatus)
  }

  ** Value out holds while an input is invalid or a fault
  private Number held(StatusNumber u) { initialized ? heldVal : initVal(u) }

  ** Write out only if it changes, so an idle execute pushes nothing
  private Void write(Number v, Status status)
  {
    o := out
    if (o != null && o.num == v && o.status == status) return
    set("out", StatusNumber(v, status))
  }

  ** CDL initial equations, at the first valid execute
  protected abstract Void init(StatusNumber u)

  ** CDL when trigger, at a rise of trigger with a valid in
  protected abstract Void sample(StatusNumber u)

  ** Value the initial equations give for u
  protected abstract Number initVal(StatusNumber u)

  ** Value of out on a valid execute
  protected abstract Number outVal()

  ** Value of out while an input is invalid or a fault
  protected virtual Number heldVal() { outVal }

  ** Status of out on a valid execute
  protected abstract Status outStatus()

  ** Is a parameter outside its CDL bounds
  protected virtual Bool paramFault() { false }

  ** Has a parameter changed since the initial equations ran
  protected virtual Bool restartNeeded() { false }
}

**
** Samples `in` on a rise of `trigger` and holds it with the status `in`
** had then.  Until the first sample `out` is `yStart`.  This is the CDL
** `Discrete.TriggeredSampler` block.
**
@Gen
class TriggeredSampler : TriggeredComp
{
  ** Value of out until the first sample
  @Gen virtual Number yStart { get {get("yStart")} set {set("yStart", it)} }

  private Bool sampled
  private Number sampleVal := Number.zero
  private Status sampleStatus := Status.ok

  ** CDL: y = y_start
  protected override Void init(StatusNumber u) { this.sampled = false }

  ** CDL: when trigger then y = u
  protected override Void sample(StatusNumber u)
  {
    this.sampled = true
    this.sampleVal = u.num
    this.sampleStatus = u.status
  }

  protected override Number initVal(StatusNumber u) { yStart }

  protected override Number outVal() { sampled ? sampleVal : yStart }

  protected override Status outStatus() { sampled ? sampleStatus : Status.ok }
}

**
** The largest absolute value of `in` over the rises of `trigger`, with
** the status of the sample that set it.  The first execute sets `out`
** to `in`, not its absolute value.  This is the CDL
** `Discrete.TriggeredMax` block.
**
@Gen
class TriggeredMax : TriggeredComp
{
  private Number maxVal := Number.zero
  private Status maxStatus := Status.ok

  ** CDL: y = u, not abs(u)
  protected override Void init(StatusNumber u)
  {
    this.maxVal = u.num
    this.maxStatus = u.status
  }

  ** CDL: when trigger then y = max(pre(y), abs(u)).  A tie keeps the
  ** earlier sample.
  protected override Void sample(StatusNumber u)
  {
    a := u.num.abs
    if (a.toFloat <= maxVal.toFloat) return
    this.maxVal = a
    this.maxStatus = u.status
  }

  protected override Number initVal(StatusNumber u) { u.num }

  protected override Number outVal() { maxVal }

  protected override Status outStatus() { maxStatus }
}
