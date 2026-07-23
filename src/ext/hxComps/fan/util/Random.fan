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
** Generates a random number such that `out = random() * multiplier + offset`
** where `random()` generates a number between 0.0 (inclusive) and 1.0 (exclusive)
**
@Gen
class Random : HxComp
{
  ** Then current random number
  @Gen virtual StatusNumber out() { get("out") }

  ** The multiplier
  @Gen virtual Float multiplier { get {get("multiplier")} set {set("multiplier", it)} }

  ** The offset
  @Gen virtual Float offset { get {get("offset")} set {set("offset", it)} }

  ** How frequently to update the output
  @Gen virtual Duration freq { get {get("freq")} set {set("freq", it)} }

  new make()
  {
  }

  override Duration? onExecuteFreq()
  {
    freq := this.freq
    if (freq == 0sec) return null
    return freq
  }

  override Void onChange(CompChangeEvent e)
  {
    if ("freq" == e.name && freq < 1sec)
    {
      this.freq = 1sec
    }
  }

  override Void onExecute()
  {
    r := Number(Float.random() * multiplier + offset)
    set("out", StatusNumber(r))
  }
}

