//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Sep 2024  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Contains a slot for each status flag
**
@NoDoc
class StatusTestComp : HxComp
{

  /* ionc-start */

  virtual StatusNumber ok() { get("ok") }

  virtual StatusNumber alarm() { get("alarm") }

  virtual StatusNumber disabled() { get("disabled") }

  virtual StatusNumber down() { get("down") }

  virtual StatusNumber fault() { get("fault") }

  virtual StatusNumber nullVal() { get("nullVal") }

  virtual StatusNumber overridden() { get("overridden") }

  virtual StatusNumber stale() { get("stale") }

  virtual StatusNumber unacked() { get("unacked") }

  /* ionc-end */


  override Duration? onExecuteFreq()
  {
    2sec
  }

  override Void onExecute()
  {
    val := Number(count++)
    set("ok", StatusNumber(val, Status.ok))
    MStatus.names.each |n|
    {
      slot := n == "null" ? "nullVal" : n
      set(slot, StatusNumber(val, Status.fromName(n)))
    }
  }

  private Float count
}

