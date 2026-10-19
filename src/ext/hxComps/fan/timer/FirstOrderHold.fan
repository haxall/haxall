//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Follows a line through the last two samples of `in`, one period late:
** from the instant of sample k to the next,
** `out = u[k-1] + (u[k] - u[k-1]) * (time - t[k]) / period`.  This is the
** CDL `Discrete.FirstOrderHold` block.  Until the first instant `out` is
** the first `in`.  Between instants `out` is updated every second while
** it moves.  `out` carries the merged status of the two samples and the
** unit of the last.  An instant with no valid `in` takes the last sample
** again, and a change of `period` restarts the line where it is, so
** `out` goes flat rather than jump.  Like `ZeroOrderHold` it does not
** cut a loop.
**
@Gen
class FirstOrderHold : SampledComp
{
  new make()
  {
  }

  ** pre_uSample: the sample before the last one
  private Float preU

  ** uSample: the last sample
  private Float lastU

  ** c, per tick
  private Float slope

  ** tSample is the execute that took the sample less ago ticks
  private DateTime? sampledAt
  private Int ago

  private Unit? unit

  private Status preStatus := Status.ok
  private Status lastStatus := Status.ok

  ** y at the last valid execute, held while in is not valid
  private Float y

  ** CDL: pre(uSample) = pre(pre_uSample) = u and pre(c) = 0.  The
  ** firstTrigger case needs no code: its instant is due only on the
  ** first execute, which samples the same u, so c is already 0.
  protected override Void init(StatusNumber u, DateTime now)
  {
    this.preU = u.num.toFloat
    this.lastU = preU
    this.slope = 0f
    this.sampledAt = now
    this.ago = 0
    this.unit = u.num.unit
    this.preStatus = u.status
    this.lastStatus = u.status
    this.y = preU
  }

  ** CDL: when sampleTrigger then c = (uSample - pre_uSample)/samplePeriod.
  ** tSample is the instant, not the execute.
  protected override Void sample(StatusNumber u, DateTime now, Int period, Int ago)
  {
    this.preU = lastU
    this.lastU = u.num.toFloat
    this.slope = (lastU - preU) / period.toFloat
    this.sampledAt = now
    this.ago = ago
    this.unit = u.num.unit
    this.preStatus = lastStatus
    this.lastStatus = u.status
  }

  ** An instant passed with no valid in: take the last sample again
  protected override Void pass(DateTime now, Int ago)
  {
    this.preU = lastU
    this.slope = 0f
    this.sampledAt = now
    this.ago = ago
  }

  ** The clock restarted: go flat where the line is, or at the held value
  ** if the last execute was not valid, so out does not jump
  protected override Void restart(DateTime now, Bool live)
  {
    if (live) update(now)
    this.preU = y
    this.lastU = y
    this.slope = 0f
    this.sampledAt = now
    this.ago = 0
  }

  protected override Bool moving() { slope != 0f }

  ** CDL: y = pre_uSample + pre(c)*(time - tSample).  A clock moved back
  ** runs back along the line, but not past the last instant.
  protected override Number update(DateTime now)
  {
    dt := (now - sampledAt).ticks.toFloat + ago.toFloat
    if (dt < 0f) dt = 0f
    this.y = preU + slope * dt
    return Number(y, unit)
  }

  protected override Number heldVal() { Number(y, unit) }

  protected override Status outStatus() { preStatus.merge(lastStatus) }
}
