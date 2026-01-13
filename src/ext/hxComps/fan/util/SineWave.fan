//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Aug 2024  Matthew Giannini  Creation
//

using xeto
using haystack

**
** The output of this component generates a sine wave.
**
class SineWave : HxComp
{

  /* ionc-start */

  ** The computed sine wave
  virtual StatusNumber out() { get("out") }

  ** The amount of time it takes to output one complete cycle
  virtual Duration period { get {get("period")} set {set("period", it)} }

  ** The height of the sine wave from its lowest to highest point
  virtual Float amplitude { get {get("amplitude")} set {set("amplitude", it)} }

  ** The distance from zero that the sine wave's amplitude is shifted
  virtual Float offset { get {get("offset")} set {set("offset", it)} }

  ** How frequently to compute the sine wave
  virtual Duration freq { get {get("freq")} set {set("freq", it)} }

  /* ionc-end */

  new make()
  {
    this.startTicks = DateTime.defVal.ticks
  }

  private Int startTicks

  override Duration? onExecuteFreq()
  {
    freq := this.freq
    if (freq == 0sec) return null
    return freq
  }

  override Void onChange(CompChangeEvent e)
  {
    // ensure freq is at least 1sec
    if (e.name == "freq" && freq < 1sec)
    {
      freq = 1sec
      this.startTicks = cx.now.ticks
    }
  }

  override Void onExecute()
  {
    runtime := cx.now.ticks - startTicks
    nanosIntoPeriod := runtime % period.ticks
    percent := nanosIntoPeriod.toFloat / period.ticks.toFloat
    angle := 2.0f * Float.pi * percent

    set("out", StatusNumber(Number(angle.sin * amplitude + offset), Status.ok))
  }

}

