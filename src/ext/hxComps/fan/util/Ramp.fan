//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** The output of this component generates a ramp waveform.
**
@Gen
class Ramp : HxComp
{
  ** The computed ramp value
  @Gen virtual StatusNumber out() { get("out") }

  ** The amount of time it takes to output one complete cycle
  @Gen virtual Duration period { get {get("period")} set {set("period", it)} }

  ** The height of the ramp from its lowest to highest point
  @Gen virtual Float amplitude { get {get("amplitude")} set {set("amplitude", it)} }

  ** The distance from zero that the ramp's amplitude is shifted
  @Gen virtual Float offset { get {get("offset")} set {set("offset", it)} }

  ** How frequently to compute the ramp
  @Gen virtual Duration freq { get {get("freq")} set {set("freq", it)} }

  ** The type of ramp waveform to produce
  @Gen virtual RampWaveform waveform { get {get("waveform")} set {set("waveform", it)} }

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


**
** Waveforms available to the Ramp component.
**
@Gen
enum class RampWaveform
{
  triangle,

  sawtooth,

  invertedSawtooth
}

