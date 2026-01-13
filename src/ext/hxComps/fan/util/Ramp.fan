//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class Ramp : HxComp
{
  /* ionc-start */

  ** The computed ramp value
  virtual StatusNumber out() { get("out") }

  ** The amount of time it takes to output one complete cycle
  virtual Duration period { get {get("period")} set {set("period", it)} }

  ** The height of the ramp from its lowest to highest point
  virtual Float amplitude { get {get("amplitude")} set {set("amplitude", it)} }

  ** The distance from zero that the ramp's amplitude is shifted
  virtual Float offset { get {get("offset")} set {set("offset", it)} }

  ** How frequently to compute the ramp
  virtual Duration freq { get {get("freq")} set {set("freq", it)} }

  ** The type of ramp waveform to produce
  virtual RampWaveform waveform { get {get("waveform")} set {set("waveform", it)} }

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
    // ensure update interval is at least 1sec
    if ("freq" == e.name && freq < 1sec)
    {
      freq = 1sec
      this.startTicks = cx.now.ticks
    }
  }

  override Void onExecute()
  {
    periodTicks := period.ticks
    runtime := cx.now.ticks - startTicks
    nanosIntoPeriod := runtime % periodTicks
    percent := nanosIntoPeriod.toFloat / periodTicks.toFloat

    Float? nextVal
    switch (waveform)
    {
      case RampWaveform.triangle:
        trianglePercent := percent < 0.5f ? percent : 1f - percent
        nextVal = offset - amplitude + ((trianglePercent * amplitude) * 4)
      case RampWaveform.sawtooth:
        nextVal = offset - amplitude + (percent * amplitude * 2f)
      case RampWaveform.invertedSawtooth:
        nextVal = offset - amplitude + ((1-percent) * amplitude * 2f)
    }

    set("out", StatusNumber(Number(nextVal), Status.ok))
  }
}


enum class RampWaveform
{
  /* ionc-start */

  triangle,

  sawtooth,

  invertedSawtooth

  /* ionc-end */
}

