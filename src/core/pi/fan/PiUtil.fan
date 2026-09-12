//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Apr 2024  Brian Frank  Sandbridge
//   12 Sep 2026  Brian Frank  Move from ion
//

using concurrent
using util
using xeto
using haystack

**
** Presentation information utilities
**
@NoDoc @Js
const class PiUtil
{

//////////////////////////////////////////////////////////////////////////
// Localization
//////////////////////////////////////////////////////////////////////////

  ** Lookup localization key in the `pi` pod which centralizes all keys
  static Str? locale(Str key, Str? def := key)
  {
    Text#.pod.locale(key, def)
  }

  ** Map programmatic name to default display name
  **   - foo     => Foo
  **   - foo-bar => Foo Bar
  **   - fooBar  => Foo Bar
  @NoDoc static Str nameToDis(Str name)
  {
    s := StrBuf(name.size)
    name.each |ch, i|
    {
      if (i == 0) { s.addChar(ch.upper); return }
      prev := s.get(-1)
      if (ch == '-') s.addChar(' ')
      else if (ch.isUpper && prev != ' ') s.addChar(' ').addChar(ch)
      else if (prev == ' ') s.addChar(ch.upper)
      else s.addChar(ch)
    }
    dis := s.toStr
    if (dis == name) return name
    return dis
  }

//////////////////////////////////////////////////////////////////////////
// Item Utils
//////////////////////////////////////////////////////////////////////////

  ** Item to dict
  @NoDoc static Dict itemToDict(Item? item)
  {
    if (item == null) return Etc.dict0
    return item.data
    acc := Str:Obj[:]
    item.meta.each |v, n| { acc[n] = v }
    acc["dis"] = item.dis
    return Etc.makeDict(acc)
  }

  ** Sort list of of items
  @NoDoc static Item[] sort(Item[] list)
  {
    list.sort |a, b| { sortCompare(a, b) }
  }

  ** Compare two items for ordering groups
  @NoDoc static Int sortCompare(Item a, Item b)
  {
    ao := int(a.meta["order"], 500)
    bo := int(b.meta["order"], 500)
    if (ao != null)
    {
      if (bo == null) return -1
      if (ao != bo) return ao <=> bo
    }
    else if (bo != null)
    {
      return 1
    }
    return a.dis <=> b.dis
  }

//////////////////////////////////////////////////////////////////////////
// Coerce
//////////////////////////////////////////////////////////////////////////

   ** Coerce value to an integer
  static Int? int(Obj? val, Int? def := null)
  {
    if (val != null)
    {
      if (val is Int) return val
      if (val is Number) return ((Number)val).toInt
      if (val is Float) return ((Float)val).toInt
    }
    return def
  }

}

