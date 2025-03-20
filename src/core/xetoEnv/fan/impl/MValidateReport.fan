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
  new make(ValidateLevel level, Dict subject, Str[] slotPath, Str msg)
  {
    this.level    = level
    this.subject  = subject
    this.slotPath = slotPath
    this.msg      = msg
  }

  override const ValidateLevel level
  override const Dict subject
  override const Str[] slotPath
  override const Str msg

  override Str toStr()
  {
    s := StrBuf()
    s.add(level)
    id := subject["id"]
    if (id != null) s.add(" @").add(id)
    if (!slotPath.isEmpty) s.add(" ").add(slotPath.join("."))
    s.add(" ").add(msg)
    return s.toStr
  }
}

