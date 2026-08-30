//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2026  Brian Frank  Creation
//

**
** Text wraps a string for display with localization macro support.
** ```
** Localization "$<key>"       // for keys in declaring pod
** Localization "$<pod::key>"  // for keys in other pods
** ```
**
@Js
const mixin Text
{
  ** Same as `empty`
  static Text defVal() { empty }

  ** Empty string
  static const Text empty := MText.make("")

  ** Create from string value
  static new fromStr(Str s) { MText.fromStr(s) }

  ** Text to display with macros evaluated
  abstract Str dis()

  ** Text pattern before macro evaluation
  abstract Str pattern()

  ** Return pattern (not dis)
  override final Str toStr() { pattern }

  ** Is this the blank / empty string
  Bool isBlank() { pattern.isEmpty }
}

**************************************************************************
** MText
**************************************************************************

**
** Text implementation
**
@NoDoc @Js
const class MText : Text
{
  static new fromStr(Str s)
  {
    if (s.isEmpty) return defVal
    return make(s)
  }

  internal new make(Str pattern) { this.pattern = pattern }

  override const Str pattern

  override Str dis() { throw Err("TODO") }

  override Int hash() { pattern.hash }

  override Bool equals(Obj? that)
  {
    a := this
    b := that as MText
    if (b == null) return false
    return a.pattern == b.pattern
  }
}
