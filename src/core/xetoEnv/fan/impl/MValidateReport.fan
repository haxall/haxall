//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Mar 2025  Brian Frank  Creation
//

using util
using xeto

**
** ValidateReport implementation
**
@Js
const class MValidateReport : ValidateReport
{
  new make(Dict[] subjects, MValidateItem[] items)
  {
    numWarns := 0
    numErrs  := 0
    items.each |item|
    {
      if (item.level.isErr) numErrs++
      else numWarns++
    }

    this.subjects = subjects
    this.items    = items
    this.numErrs  = numErrs
    this.numWarns = numWarns
  }

  override const Dict[] subjects

  override const MValidateItem[] items

  override Bool hasErrs() { numErrs > 0 }

  override const Int numErrs

  override const Int numWarns

  override ValidateItem[] itemsForSubject(Dict subject)
  {
    items.findAll |x| { x.subject === subject }
  }

  override ValidateItem[] itemsForSlot(Dict subject, Str slot)
  {
    items.findAll |x| { x.subject === subject && x.isSlotMatch(slot) }
  }

  override Void dump(Console con := Console.cur)
  {
    con.group("ValidateReport [$numErrs errs, $numWarns warns]")
    items.each |item| { con.info(item) }
    con.groupEnd
  }
}

**************************************************************************
** MValidateItem
**************************************************************************

@Js
const class MValidateItem : ValidateItem
{
  new make(ValidateLevel level, Dict subject, Str? slot, Str msg)
  {
    this.level   = level
    this.subject = subject
    this.slot    = slot
    this.msg     = msg
  }

  override const ValidateLevel level
  override const Dict subject
  override const Str? slot
  override const Str msg

  Bool isSlotMatch(Str name)
  {
    if (slot == null) return false
    if (slot == name) return true
    if (slot.contains(".")) return slot.startsWith(name) && slot.getSafe(name.size) == '.'
    return false
  }

  override Str toStr()
  {
    s := StrBuf()
    s.add(level)
    id := subject["id"]
    if (id != null) s.add(" @").add(id)
    if (slot != null) s.add(" '").add(slot).add("'")
    s.add(" ").add(msg)
    return s.toStr
  }
}

