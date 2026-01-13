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
** Generates a random number such that 'out = random() * multiplier + offset'
** where 'random()' generates a number between 0.0 (inclusive) and 1.0 (exclusive)
**
class Random : HxComp
{
  /* ionc-start */

  ** Then current random number
  virtual StatusNumber out { get {get("out")} set {set("out", it)} }

  ** The multiplier
  virtual Float multiplier { get {get("multiplier")} set {set("multiplier", it)} }

  ** The offset
  virtual Float offset { get {get("offset")} set {set("offset", it)} }

  ** How frequently to update the output
  virtual Duration freq { get {get("freq")} set {set("freq", it)} }

  /* ionc-end */

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

