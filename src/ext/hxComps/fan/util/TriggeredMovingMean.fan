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
** The mean of the last `n` samples of `in`.  The first execute and each
** rise of `trigger` take a sample, and until `n` are taken the mean is
** over those there are.  `out` carries the merged status of the samples
** in the mean and the unit of the last one.  An `n` below 1 faults, and
** a change of `n` starts the mean again.  This is the CDL
** `Discrete.TriggeredMovingMean` block.
**
@Gen
class TriggeredMovingMean : TriggeredComp
{
  ** Number of samples in the mean, at least 1
  @Gen virtual Int n { get {get("n")} set {set("n", it)} }

  ** The n the samples were taken for
  private Int size

  ** CDL ySample; the entries CDL starts at zero are not kept
  private Float[] samples := Float[,]
  private Status[] statuses := Status[,]

  ** CDL iSample: the number of samples taken
  private Int count

  private Unit? unit

  ** CDL n(min = 1)
  protected override Bool paramFault() { n < 1 }

  protected override Bool restartNeeded() { n != size }

  ** CDL when initial(): the initial execute is the first sample
  protected override Void init(StatusNumber u)
  {
    this.size = n
    this.samples = Float[,]
    this.statuses = Status[,]
    this.count = 0
    sample(u)
  }

  ** CDL when trigger: ySample[mod(pre(iSample), n) + 1] = u
  protected override Void sample(StatusNumber u)
  {
    i := count % size
    if (i < samples.size)
    {
      samples[i] = u.num.toFloat
      statuses[i] = u.status
    }
    else
    {
      samples.add(u.num.toFloat)
      statuses.add(u.status)
    }
    this.count = count + 1
    this.unit = u.num.unit
  }

  protected override Number initVal(StatusNumber u) { u.num }

  ** CDL y = sum(ySample) / counter, where counter is the samples kept
  protected override Number outVal()
  {
    sum := 0f
    samples.each |x| { sum += x }
    return Number(sum / samples.size.toFloat, unit)
  }

  protected override Status outStatus()
  {
    Status s := Status.ok
    statuses.each |x| { s = s.merge(x) }
    return s
  }
}
