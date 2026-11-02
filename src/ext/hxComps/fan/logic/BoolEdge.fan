//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Detects a change of a bool input: `out` is true for one execute after
** each change of `in` that `edge` selects, and false otherwise.  `out`
** clears on the next cycle even when nothing else changes.  This covers
** the CDL `Logical.Edge`, `Logical.FallingEdge` and `Logical.Change`
** blocks.  A null `in` sets `out` to null and keeps the previous `in`.  An
** invalid `in` is not compared, and `out` is false with its status, or
** stays null after a null.  After a restart the first valid execute
** compares `in` with `initPrev` again.
**
@Gen
class BoolEdge : Logic
{
  ** Input to watch
  @Gen virtual StatusBool? in() { get("in") }

  ** Which change of `in` sets `out`
  @Gen virtual BoolEdgeType edge { get {get("edge")} set {set("edge", it)} }

  ** The previous value of `in` assumed by the first execute
  @Gen virtual Bool initPrev { get {get("initPrev")} set {set("initPrev", it)} }

  private Bool initialized
  private Bool lastIn

  override Void onExecute()
  {
    u := in

    if (u == null) return set("out", null)

    if (!u.status.isValid)
    {
      if (get("out") != null) set("out", StatusBool(false, u.status))
      return
    }

    pre := initialized ? lastIn : initPrev
    initialized = true
    lastIn = u.val

    v := false
    switch (edge)
    {
      case BoolEdgeType.rising:  v = u.val && !pre   // edge(u)
      case BoolEdgeType.falling: v = !u.val && pre   // edge(not u)
      case BoolEdgeType.change:  v = u.val != pre    // change(u)
    }
    set("out", StatusBool(v, u.status))

    // a pulse lasts one execute: run the next cycle to clear it
    if (v) execute
  }
}

**
** Changes of `in` that BoolEdge detects
**
@Gen
enum class BoolEdgeType
{
  ** `in` turns from false to true
  rising,

  ** `in` turns from true to false
  falling,

  ** `in` turns either way
  change
}
