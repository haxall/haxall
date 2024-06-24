//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jun 2024  Brian Frank  New plan!
//

using util
using xeto

**
** CompListeners manages lifecycle callbacks
**
@Js
internal class CompListeners
{
  Void onChangeAdd(Str name, |Comp,Obj?| cb)
  {
    add(name, CompOnChangeListener(cb))
  }

  Void onCallAdd(Str name, |Comp,Obj?| cb)
  {
    add(name, CompOnCallListener(cb))
  }

  Void onChangeRemove(Str name, Func cb)
  {
    remove(name, cb)
  }

  Void onCallRemove(Str name, Func cb)
  {
    remove(name, cb)
  }

  Void add(Str name, CompSlotListener x)
  {
    // add to end of the linked list
    p := bySlot[name]
    if (p == null)
    {
      bySlot[name] = x
    }
    else
    {
      while (p.next != null) p = p.next
      p.next = x
    }
  }

  Void remove(Str name, Func cb)
  {
    p := bySlot[name]
    if (p == null) return
    if (p.cb === cb)
    {
      if (p.next == null)
        bySlot.remove(name)
      else
        bySlot[name] = p.next
    }
    else
    {
      while (p.next != null)
      {
        if (p.next.cb === cb)
        {
          p.next = p.next.next
          break
        }
      }
    }
  }

  Void fireOnChange(Comp c, Str name, Obj? newVal)
  {
    p := bySlot[name]
    while (p != null)
    {
      p.fireOnChange(c, newVal)
      p = p.next
    }
  }

  Void fireOnCall(Comp c, Str name, Obj? arg)
  {
    p := bySlot[name]
    while (p != null)
    {
      p.fireOnCall(c, arg)
      p = p.next
    }
  }

  /*
  Void dump()
  {
    echo("--- CompListeners --")
    bySlot.each |CompSlotListener? p, n|
    {
      echo("-- $n")
      while (p != null) { echo("  $p"); p = p.next }
    }
  }
  */

  private Str:CompSlotListener bySlot := [:]
}

**************************************************************************
** CompSlotListeners
**************************************************************************

**
** CompSlotListeners stores callbacks as linked list
**
@Js
internal abstract class CompSlotListener
{
  new make(|Comp,Obj?| cb) { this.cb = cb }
  virtual Void fireOnChange(Comp c, Obj? v) {}
  virtual Void fireOnCall(Comp c, Obj? v) {}
  CompSlotListener? next
  |Comp,Obj?| cb
}

@Js
internal final class CompOnChangeListener : CompSlotListener
{
  new make(|Comp,Obj?| cb) : super(cb) {}
  override Void fireOnChange(Comp c, Obj? v) { cb(c, v) }
}

@Js
internal final class CompOnCallListener : CompSlotListener
{
  new make(|Comp,Obj?| cb) : super(cb) {}
  override Void fireOnCall(Comp c, Obj? v) { cb(c, v) }
}

