//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   07 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Generates an oscillating binary pulse
**
class MultiVibrator : HxComp
{
  /* ionc-start */

  ** The current pulse value
  virtual StatusBool out() { get("out") }

  ** How long it takes to complete a single on-off cycle
  virtual Duration period { get {get("period")} set {set("period", it)} }

  ** Configures the percentage of time during the period that the
  ** signal is active (true).
  virtual Int dutyCycle { get {get("dutyCycle")} set {set("dutyCycle", it)} }

  /* ionc-end */

  new make()
  {
  }

  private Int startLow
  private Int endPeriod
  private Bool initialized := false

  override Duration? onExecuteFreq() { 10ms }

  override Void onChange(CompChangeEvent e)
  {
    if (!isMounted) return
    switch (e.name)
    {
      case "period":
      case "dutyCycle":
        // fall-through
        resetTimers
    }
  }

  private Void resetTimers()
  {
    period := this.period.max(200ms)

    cycle := dutyCycle
    if (cycle < 0) cycle = 0
    else if (cycle > 100) cycle = 100

    this.startLow  = cx.now.ticks + (period * (cycle/100f)).ticks
    this.endPeriod = cx.now.ticks + period.ticks
  }

  override Void onExecute()
  {
    // unfortunate to need this, but cx not available in onMount
    if (!initialized) { resetTimers; this.initialized = true }

    nowTicks := cx.now.ticks
    if (nowTicks < startLow) set("out", StatusBool(true))
    else if (nowTicks < endPeriod) set("out", StatusBool(false))
    else { resetTimers; set("out", StatusBool(true)) }
  }

}

