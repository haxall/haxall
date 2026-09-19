//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Mar 2025  Brian Frank  Creation
//

using util
using xeto
using haystack
using haystack::Macro

@Js
const class MValidateItem : ValidateItem
{
  new make(ValidateRule r, ValidateState s, Dict args)
  {
    this.rule    = r.id
    this.level   = r.level
    this.subject = s.subject
    this.slot    = s.slotPath
    this.val     = s.val
    this.loc     = s.loc
    this.msg     = Macro(r.msg).apply |n| { macroResolve(n, r, s, args) ?: "?" }
  }

  private Str? macroResolve(Str n, ValidateRule r, ValidateState s, Dict args)
  {
    // state specials
    switch (n)
    {
      case "val":     return val?.toStr
      case "slot":    return slot
      case "type":    return s.spec.type.qname
      case "valType": return s.valType?.qname ?: val?.typeof?.qname
      case "size":    return valSize
    }

    // rule supplied args, then fall thru to spec effective meta
    // so templates can reference constraints such as $minVal
    v := args.get(n) ?: s.spec.meta.get(n)
    return v?.toStr
  }

  ** Size of current value for Str/List or null
  private Str? valSize()
  {
    if (val is Str)  return ((Str)val).size.toStr
    if (val is List) return ((List)val).size.toStr
    return null
  }

  override const Ref rule
  override const ValidateLevel level
  override const Dict subject
  override const Str? slot
  override const Str msg
  override const Obj? val
  override const FileLoc loc

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

