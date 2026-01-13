//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Current clock time
**
class CurTime : HxComp
{
  /* ionc-start */

  ** How frequently to update the current time
  virtual Duration updateFreq { get {get("updateFreq")} set {set("updateFreq", it)} }

  ** The current time
  virtual DateTime out() { get("out") }

  /* ionc-end */

  new make()
  {
    this.nextUpdateTicks = DateTime.defVal.ticks
  }

  private Int nextUpdateTicks

  override Duration? onExecuteFreq()
  {
    this.updateFreq
  }

  override Void onChange(CompChangeEvent e)
  {
    if (e.name == "updateFreq" && updateFreq < 0.5sec)
    {
      // ensure update freq is at least 0.5sec
      updateFreq = 0.5sec
    }
  }

  override Void onExecute()
  {
    now := cx.now
    if (now.ticks < nextUpdateTicks) return
    set("out", now)
    this.nextUpdateTicks = now.ticks + updateFreq.ticks
  }
}

