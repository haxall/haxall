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
** Counts the times `trigger` turns true, starting from `initVal`.  When
** `reset` turns true, or `trigger` turns true while `reset` is true,
** `out` goes back to `initVal`.  This is the CDL `Integers.OnCounter`
** block.  A null input sets `out` to null and an invalid one holds
** `out`.  Both keep the count.
**
@Gen
class Counter : HxComp
{
  ** Adds one to `out` when it turns true
  @Gen virtual StatusBool? trigger { get {get("trigger")} set {set("trigger", it)} }

  ** Sets `out` back to `initVal` when it turns true.  Link a `BoolConst`
  ** false when no reset is needed: an unlinked `reset` keeps `out` null.
  @Gen virtual StatusBool? reset { get {get("reset")} set {set("reset", it)} }

  ** The value of `out` at the first execute and after a reset
  @Gen virtual Int initVal { get {get("initVal")} set {set("initVal", it)} }

  ** The count
  @Gen virtual StatusNumber? out() { get("out") }

  new make()
  {
  }

  private Bool initialized
  private Bool lastTrigger
  private Bool lastReset
  private Int count

  override Void onExecute()
  {
    t := this.trigger
    r := this.reset
    if (t == null || r == null) return set("out", null)

    // after a null input out stays null until valid inputs arrive
    status := t.status.merge(r.status)
    if (!t.status.isValid || !r.status.isValid)
    {
      if (initialized && out != null) write(status)
      return
    }

    tv := t.val
    rv := r.val
    if (!initialized)
    {
      // OnCounter's when clause does not fire at init
      this.initialized = true
      this.count = initVal
    }
    else if ((tv && !lastTrigger) || (rv && !lastReset))
    {
      // OnCounter reads the level of reset when either input rises
      this.count = rv ? initVal : count + 1
    }
    this.lastTrigger = tv
    this.lastReset = rv
    write(status)
  }

  private Void write(Status status)
  {
    set("out", StatusNumber(Number.makeInt(count), status))
  }
}
