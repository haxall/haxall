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
  internal new make(Obj? val) { this.val = this.pushVal = val }

  ** Const for this type
  static const Type type := FatSlot#

  ** Sentinel for pushing null
  static const Obj nullPush := "__null_push__"

  ** Wrapped value or null for methods
  internal Obj? val { private set }

//////////////////////////////////////////////////////////////////////////
// Updates and Push
//////////////////////////////////////////////////////////////////////////

  ** Update value and enqueue push when component slot set
  Void set(Obj val) { this.val = this.pushVal = val }

  ** Enqueue push when component method is called
  Void called(Obj? ret) { this.pushVal = ret ?: nullPush }

  ** Push to target components if there an enqueued value
  Void push()
  {
    // short circuit if no enqueued push value
    val := pushVal
    if (val == null) return
    if (val === nullPush) val = null

    // clear enqueued push value
    pushVal = null

    // push to everyone in my pushTo linked list
    for (p := pushToHead; p != null; p = p.next) pushTo(p, val)

  }

  ** Push to given component and slot
  private Void pushTo(FatSlotPushTo x, Obj? val)
  {
    c := x.toComp
    if (c.hasMethod(x.toSlot))
      c.call(x.toSlot, val)
    else
      c.set(x.toSlot, val)
  }

  ** Enqueued value to push to targets
  private Obj? pushVal

//////////////////////////////////////////////////////////////////////////
// Topology push to targets
//////////////////////////////////////////////////////////////////////////

  ** Clear linked list of push targets
  internal Void clearPushTo() { pushToHead = null }

  ** Add push target
  internal Void addPushTo(Comp toComp, Str toSlot)
  {
    t := FatSlotPushTo(toComp, toSlot)
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
}

