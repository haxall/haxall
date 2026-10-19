//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2025  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** FatSlot is used to wrap MCompSpi slot values that have outgoing
** links to manage pushing the value to the target component.
**
@Js
final class FatSlot
{
  ** Constructor
  internal new make(Obj? val)
  {
    this.val = val
    if (val != null) queuePush(val)
  }

  ** Const for this type
  static const Type type := FatSlot#

  ** Sentinel for pushing null
  static const Obj nullPush := "__null_push__"

  ** Wrapped value or null if undefined fat slot
  internal Obj? val { private set }

//////////////////////////////////////////////////////////////////////////
// Updates and Push
//////////////////////////////////////////////////////////////////////////

  ** Update value and enqueue push when component slot set.  A null
  ** keeps this fat slot and its push targets, and pushes the null.
  Void set(Obj? val) { this.val = val; queuePush(val) }

  ** Enqueue push when component method is called
  Void called(Obj? ret) { queuePush(ret) }

  ** Queue up value to push
  private Void queuePush(Obj? x) { pushVal = x ?: nullPush }

  ** Push to target components if there an enqueued value
  internal Void push(Comp fromComp, Str fromSlot)
  {
    // short circuit if no enqueued push value
    val := pushVal
    if (val == null) return
    if (val === nullPush) val = null

    // clear enqueued push value
    pushVal = null

    // push to everyone in my pushTo linked list
    for (p := pushToHead; p != null; p = p.next) pushTo(fromComp, fromSlot, p, val)
  }

  ** Push to given component and slot.  A null into a slot that is not
  ** maybe is skipped and an error from the target is caught.  Both are
  ** logged, not raised, so one bad target does not stop the cycle.  A
  ** self link that removes a dynamic slot of the pushing comp still
  ** throws, from the 'eachFat' iteration in 'MCompSpi.checkPush'.
  private Void pushTo(Comp fromComp, Str fromSlot, FatSlotPushTo x, Obj? val)
  {
    toComp := x.toComp
    toSlot := x.toSlot
    try
    {
      if (toComp.hasFunc(toSlot))
      {
        toComp.call(toSlot, val)
      }
      else
      {
        if (val == null && !acceptsNull(toComp, toSlot))
        {
          x.pushFailed(fromComp, fromSlot, "null not pushed, target slot is not maybe", null)
          return
        }
        toComp.set(toSlot, val)
      }
      x.pushOk(fromComp, fromSlot)
    }
    catch (Err e)
    {
      x.pushFailed(fromComp, fromSlot, "push failed: $e", e)
    }
  }

  ** Can the given component slot be set to null
  private static Bool acceptsNull(Comp c, Str name)
  {
    slot := c.spec.slot(name, false)
    return slot == null || slot.isMaybe
  }

  ** Enqueued value to push to targets
  private Obj? pushVal

//////////////////////////////////////////////////////////////////////////
// Topology push to targets
//////////////////////////////////////////////////////////////////////////

  ** Clear linked list of push targets, keeping the old list until
  ** 'endPushTo' so 'addPushTo' can carry each target's failure state
  internal Void clearPushTo() { prevPushToHead = pushToHead; pushToHead = null }

  ** Release the old push target list after a rebuild, to free memory
  internal Void endPushTo() { prevPushToHead = null }

  ** Does this fat slot have any push targets
  internal Bool hasPushTo() { pushToHead != null }

  ** Add push target, carrying over the failure state of the same
  ** target from before the rebuild so it is not logged again
  internal Void addPushTo(Comp toComp, Str toSlot)
  {
    t := FatSlotPushTo(toComp, toSlot)
    for (p := prevPushToHead; p != null; p = p.next)
    {
      if (p.toComp === toComp && p.toSlot == toSlot) { t.carryFailure(p); break }
    }
    t.next = pushToHead
    pushToHead = t
  }

  ** Iterate push targets
  Void eachPushTo(|FatSlotPushTo| f)
  {
    for (p := pushToHead; p != null; p = p.next) f(p)
  }

  ** Linked list of fat slot targets
  private FatSlotPushTo? pushToHead

  ** Push targets before the topology rebuild in progress, or null
  private FatSlotPushTo? prevPushToHead
}

**************************************************************************
** FatSlotPushTo
**************************************************************************

**
** FatSlotPushTo is a node in a link list of slot push targets
**
@Js
final class FatSlotPushTo
{
  ** Constructor
  internal new make(Comp c, Str s) { this.toComp = c; this.toSlot = s }

  ** Target component
  Comp toComp { private set }

  ** Target slot name
  const Str toSlot

  ** Debug string
  override Str toStr() { "@${toComp.id}.$toSlot" }

  ** Next node in linked list
  internal FatSlotPushTo? next

//////////////////////////////////////////////////////////////////////////
// Push failures
//////////////////////////////////////////////////////////////////////////

  ** Is the most recent push to this target skipped or failed
  @NoDoc Bool isFailing { private set }

  ** Number of failures since the logged one, while failing
  @NoDoc Int numSuppressed { private set }

  ** Report a skipped or failed push.  Only the first failure in a run
  ** is logged, and the rest are counted until recovery.
  internal Void pushFailed(Comp fromComp, Str fromSlot, Str msg, Err? err)
  {
    if (isFailing) { numSuppressed++; return }
    isFailing = true
    line := "${linkStr(fromComp, fromSlot)}: $msg (repeats not logged until it recovers)"
    log := ((MCompSpi)fromComp.spi).csSpi
    if (err == null) log.warn(line)
    else log.err(line, err)
  }

  ** Report a successful push, which logs a recovery after failures
  internal Void pushOk(Comp fromComp, Str fromSlot)
  {
    if (!isFailing) return
    isFailing = false
    log := ((MCompSpi)fromComp.spi).csSpi
    log.info("${linkStr(fromComp, fromSlot)}: push recovered (repeats not logged: $numSuppressed)")
    numSuppressed = 0
  }

  ** Copy failure state from the node this one replaces in a rebuild
  internal Void carryFailure(FatSlotPushTo old)
  {
    isFailing = old.isFailing
    numSuppressed = old.numSuppressed
  }

  ** Debug string for the link this node pushes along
  private Str linkStr(Comp fromComp, Str fromSlot)
  {
    "Link @${fromComp.id}.$fromSlot -> $this"
  }
}

