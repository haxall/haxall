//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Logs a run of captures that a hold keeps through a null, invalid or
** NaN in, which its ok out does not show: a warning at the onset, a line
** at the end, and a count of the repeats between.
**
internal class HoldLog
{
  ** Is a run of held captures in progress
  Bool isHolding { private set }

  ** Held captures since the logged onset, while holding
  Int numSuppressed { private set }

  ** A capture of u was held at the register value reg
  Void held(Comp c, StatusNumber? u, Number reg)
  {
    if (isHolding) { numSuppressed++; return }
    isHolding = true
    log.warn("${name(c)}: ${reason(u)}, holding $reg (repeats not logged until it recovers)")
  }

  ** A good capture: logs the end of a run
  Void ok(Comp c)
  {
    if (!isHolding) return
    isHolding = false
    log.info("${name(c)}: hold recovered (repeats not logged: $numSuppressed)")
    numSuppressed = 0
  }

  ** The run ends for a reason other than a good capture
  Void end(Comp c, Str why)
  {
    if (!isHolding) return
    isHolding = false
    log.info("${name(c)}: hold ended, $why (repeats not logged: $numSuppressed)")
    numSuppressed = 0
  }

  private static Str name(Comp c) { "${c.spec.name} @${c.id}.in" }

  private static Str reason(StatusNumber? u)
  {
    if (u == null) return "null captured"
    if (!u.status.isValid) return "status $u.status captured"
    return "NaN captured"
  }

  private static const Log log := Log.get("hxComps")
}
