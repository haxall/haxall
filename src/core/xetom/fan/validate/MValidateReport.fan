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

