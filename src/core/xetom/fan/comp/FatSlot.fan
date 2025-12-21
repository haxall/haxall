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
  new make(Obj? val) { this.val = val }

  ** const for this type
  static const Type type := FatSlot#

  ** Wrapped value or null for methods
  internal Obj? val

  ** Enqueued value to push to targets
  internal Obj? pushVal

  ** Clear linked list of push targets
  internal Void clearPushTo() { pushTo = null }

  ** Add push target
  internal Void addPushTo(Comp toComp, Str toSlot)
  {
    t := FatSlotPushTo(toComp, toSlot)
    t.next = pushTo
    pushTo = t
  }

  ** Iterate push targets
  Void eachPushTo(|FatSlotPushTo| f)
  {
    for (p := pushTo; p != null; p = p.next) f(p)
  }

  ** Linked list of fat slot targets
  private FatSlotPushTo? pushTo
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

