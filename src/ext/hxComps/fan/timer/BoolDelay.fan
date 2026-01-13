//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Bool delay
**
class BoolDelay : HxComp
{
  /* ionc-start */

  ** Input to the delay.
  virtual StatusBool? in() { get("in") }

  ** How long to wait before setting the out slot to true when
  ** the in slot transitions to true.
  virtual Duration onDelay { get {get("onDelay")} set {set("onDelay", it)} }

  ** How long to wait before setting the out slot to false when
  ** the in slot transitions to false.
  virtual Duration offDelay { get {get("offDelay")} set {set("offDelay", it)} }

  ** The value of the in slot after any delays are accounted for.
  virtual StatusBool? out() { get("out") }

  ** The inverse of the current out slot.
  virtual StatusBool? outNot() { get("outNot") }

  /* ionc-end */

  new make()
  {
    this.prevIn = this.in?.val
  }

  ** previous in slot value
  private Bool? prevIn

  override Duration? onExecuteFreq()
  {
    onDelay.min(offDelay).max(100ms) / 2
  }

  override Void onChange(CompChangeEvent e)
  {
    if (e.name == "in")
    {
      newIn := e.newVal as StatusBool
      if (newIn?.val == prevIn) return

      if (newIn != null && !newIn.status.isValid) return

      // if newIn is null do we set out immediately to null?
    }
  }

  override Void onExecute()
  {
  }
}

