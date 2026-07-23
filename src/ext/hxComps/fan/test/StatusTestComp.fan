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
@Gen
class StatusTestComp : HxComp
{

  @Gen virtual StatusNumber ok() { get("ok") }

  @Gen virtual StatusNumber alarm() { get("alarm") }

  @Gen virtual StatusNumber disabled() { get("disabled") }

  @Gen virtual StatusNumber down() { get("down") }

  @Gen virtual StatusNumber fault() { get("fault") }

  @Gen virtual StatusNumber nullVal() { get("nullVal") }

  @Gen virtual StatusNumber overridden() { get("overridden") }

  @Gen virtual StatusNumber stale() { get("stale") }

  @Gen virtual StatusNumber unacked() { get("unacked") }


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

