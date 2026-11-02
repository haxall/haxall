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
** Set-reset latch.  `out` turns true when `in` rises while `inClear` is
** false, and false when `inClear` rises, which wins when both rise on
** one execute.  This is the CDL `Logical.Latch` block.
**
** The first valid execute, also after a restart, sets `out` to `in` and
** not `inClear`.  A null input sets `out` to null, an invalid one holds
** `out` with the merged status, and edges are judged against the last
** valid inputs.  A rise of a valid `inClear` clears even while `in` is
** null or invalid.
**
@Gen
class SetResetLatch : Logic
{
  ** A rise sets `out` to true unless `inClear` is true
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
    s := in
    c := inClear

    // CDL clears regardless of in, even while in is null or invalid
    if (initialized && c != null && c.status.isValid && (s == null || !s.status.isValid))
    {
      if (c.val && !lastClear) outVal = false
      lastClear = c.val
    }

    if (s == null || c == null) return set("out", null)

    // invalid holds out; after a null, out stays null until valid
    status := s.status.merge(c.status)
    if (!status.isValid)
    {
      if (get("out") != null) write(status)
      return
    }

    if (!initialized)
    {
      // initial equation y = not clr and u
      outVal = !c.val && s.val
      initialized = true
    }
    else if ((s.val && !lastIn) || (c.val && !lastClear))
    {
      // when {clr, u} then y = not clr and u
      outVal = !c.val && s.val
    }
    lastIn    = s.val
    lastClear = c.val
    write(status)
  }

  private Void write(Status status) { set("out", StatusBool(outVal, status)) }
}
