//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    6 Dec 2018  Brian Frank  Original code from pim
//   23 Dec 2024  Brian Frank  Creation
//   12 Sep 2026  Brian Frank  Move from ion
//

using concurrent
using graphics
using xeto
using haystack

**
** Format is responsible for formatting values to strings
**
@NoDoc @Js
abstract const class Format
{
  ** Default formatting routes to Etc.valToDis
  static const Format defVal := DefaultFormat()

  ** Construct for string
  static new fromStr(Str s)
  {
    if (s.isEmpty) return defVal
    if (s[0] == '_')
    {
      switch (s)
      {
        case "_blank":      return BlankFormat()
        case "_actual":     return ActualFormat()
        case "_dictMinMax": return DictMinMaxFormat()
      }
    }
    return PatternFormat(s)
  }

  ** Is this the default pattern
  virtual Bool isDefault() { false }

  ** Is this the blank pattern
  virtual Bool isBlank() { false }

  ** Format the value
  Str format(Obj? val, Dict? meta := null)
  {
    if (val == null) return ""
    s := doFormat(val, meta)
    if (s != null) return s
    return Etc.valToDis(val, meta, false)
  }

  ** Subclass formatting hook
  @NoDoc protected abstract Str? doFormat(Obj val, Dict? meta)

  ** Return the pattern if is this a standard pattern formatter or
  ** null if this is a special format such as enum, viewLink, etc
  virtual Str? pattern() { null }

  ** Return debug string
  override Str toStr() { pattern ?: typeof.name }

  ** Hash code
  override Int hash() { toStr.hash }

  ** Equality
  override Bool equals(Obj? that) { typeof == that?.typeof }
}

**************************************************************************
** DefaultFormat
**************************************************************************

@Js
internal const class DefaultFormat : Format
{
  override Bool isDefault() { true }
  override Str? doFormat(Obj val, Dict? meta) { null }
}

**************************************************************************
** BlankFormat
**************************************************************************

@Js
internal const class BlankFormat : Format
{
  override Bool isBlank() { true }
  override Str? pattern() { "_blank" }
  override Str? doFormat(Obj val, Dict? meta) { "" }
}

**************************************************************************
** ActualFormat
**************************************************************************

@Js
internal const class ActualFormat : Format
{
  override Str? doFormat(Obj val, Dict? meta)
  {
    // when using formatActual flag (in shell) then don't try
    // to make duration's pretty, but rather show actual unit
    if (val is Number)
    {
       num := (Number)val
       if (num.isDuration)
         return num.toStr
       else
        return num.toLocale(null)
    }
    return null
  }
}

**************************************************************************
** PatternFormat
**************************************************************************

@Js
internal const class PatternFormat : Format
{
  new make(Str pattern) { this.pattern = pattern }

  override const Str? pattern

  override Str toStr() { pattern }

  override Str? doFormat(Obj val, Dict? meta)
  {
    try
    {
      if (val is Number)   return formatNumber(val)
      if (val is DateTime) return formatDateTime(val)
      if (val is Date)     return formatDate(val)
      if (val is Time)     return formatTime(val)
      if (val === NA.val)  return "NA"
    }
    catch (Err e) {}
    return pattern
  }

  private Str formatNumber(Number val)
  {
    // lazily create NumberFormat instance to only parse pattern once
    nf := numberFormatRef.val as NumberFormat
    numberFormatRef.val = nf = NumberFormat(pattern)
    return nf.format(val)
  }
  private const AtomicRef numberFormatRef := AtomicRef()

  private Str formatDateTime(DateTime val) { val.toLocale(pattern) }

  private Str formatDate(Date val) { val.toLocale(pattern) }

  private Str formatTime(Time val) { val.toLocale(pattern) }

  override Bool equals(Obj? that) { that is PatternFormat && pattern == ((PatternFormat)that).pattern }
}

**************************************************************************
** DictMinMaxFormat
**************************************************************************

@Js
internal const class DictMinMaxFormat : Format
{
  override Str? pattern() { "_dictMinMax" }
  override Str? doFormat(Obj val, Dict? meta)
  {
    dict := val as Dict
    if (dict == null) return Etc.valToDis(dict)
    return Etc.valToDis(dict["min"], meta) + " .. " + Etc.valToDis(dict["max"], meta)
  }
}

