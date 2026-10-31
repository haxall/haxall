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
** Toggle.  Each rise of `in` while `inClear` is false flips `out`.  A
** rise of `inClear` sets `out` to false and wins over a rise of `in` on
** the same execute.  This is the CDL `Logical.Toggle` block.
**
** The first valid execute, also after a restart, sets `out` to `in` and
** not `inClear`.  A null input sets `out` to null, an invalid one holds
** `out` with the merged status, and edges are judged against the last
** valid inputs.  A rise of a valid `inClear` clears even while `in` is
** null or invalid.
**
@Gen
class Toggle : Logic
{
  ** A rise flips `out` unless `inClear` is true
  @Gen virtual StatusBool? in() { get("in") }

  ** A rise sets `out` to false
  @Gen virtual StatusBool? inClear() { get("inClear") }

  private Bool initialized

  ** The value of out, kept while out is null or invalid
  private Bool outVal

  ** in and inClear at the last execute where each was valid
  private Bool lastIn
  private Bool lastClear

  override Void onExecute()
  {
    u := in
    c := inClear

    // CDL clears regardless of in, even while in is null or invalid
    if (initialized && c != null && c.status.isValid && (u == null || !u.status.isValid))
    {
      if (c.val && !lastClear) outVal = false
      lastClear = c.val
    }

    if (u == null || c == null) return set("out", null)

    // invalid holds out; after a null, out stays null until valid
    status := u.status.merge(c.status)
    if (!status.isValid)
    {
      if (get("out") != null) write(status)
      return
    }

    if (!initialized)
    {
      // when initial() then y = if clr then false else u
      outVal = !c.val && u.val
      initialized = true
    }
    else if (c.val && !lastClear)
    {
      // elsewhen clr then y = false
      outVal = false
    }
    else if (!c.val && u.val && !lastIn)
    {
      outVal = !outVal
    }
    lastIn    = u.val
    lastClear = c.val
    write(status)
  }

  private Void write(Status status) { set("out", StatusBool(outVal, status)) }
}
