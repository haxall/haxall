//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Apr 2024  Brian Frank  Sandbridge
//    1 Mar 2026  Brian Frank  Break out from UiUtil
//   12 Sep 2026  Brian Frank  Move from ion
//

using concurrent
using graphics
using util
using xeto
using haystack

**
** Utilities to coerce values to Fantom types
**
@NoDoc @Js
const class PiCoerce
{

  ** Return if val is  null, NA, NaN, +Inf, or -Inf
  static Bool bad(Obj? val)
  {
    if (val == null) return true
    if (val === NA.val) return true
    if (val is Number) return ((Number)val).isSpecial
    return false
  }

  ** Coerce value to an bool
  static Bool? bool(Obj? val, Bool? def := null)
  {
    if (val != null)
    {
      if (val == Marker.val) return true
      if (val == true) return true
      if (val == false) return false
    }
    return def
  }

  ** Coerce value to an string
  static Str? str(Obj? val, Str? def := null)
  {
    if (val != null)
    {
      return val.toStr
    }
    return def
  }

  ** Coerce value to list of strs
  static Str[]? strs(Obj? val, Str[]? def := null)
  {
    if (val != null)
    {
      if (val is List) return ((List)val).mapNotNull |x->Str| { str(x, null) }
      return Str[val.toStr]
    }
    return def
  }

  ** Coerce value to an number
  static Number? number(Obj? val, Number? def := null)
  {
    if (val != null)
    {
      if (val is Number) return val
      if (val is Int) return Number.makeInt(val)
      if (val is Float) return Number.make(val, null)
      //if (val is Str) { n := Number.fromStr(val, false); if (n != null) return n }
    }
    return def
  }

  ** Coerce value to an integer
  static Int? int(Obj? val, Int? def := null)
  {
    if (val != null)
    {
      if (val is Int) return val
      if (val is Number) return ((Number)val).toInt
      if (val is Float) return ((Float)val).toInt
      //if (val is Str) { i := Int.fromStr(val, 10, false); if (i != null) return i }
    }
    return def
  }

  ** Coerce value to a float
  static Float? float(Obj? val, Float? def := null)
  {
    if (val != null)
    {
      if (val is Float) return val
      if (val is Number) return ((Number)val).toFloat
      if (val is Int) return ((Int)val).toFloat
      //if (val is Str) { f := Float.fromStr(val, false); if (f != null) return f }
    }
    return def
  }

  ** Coerce value to float string
  static Str? floatStr(Obj? val)
  {
    f := float(val, null)
    if (f != null) return GeomUtil.formatFloat(f)
    return null
  }

  ** Coerce value to a float as pixel dimension
  static Float? dimension(Obj? val, Float? def := null)
  {
    float(val, def)
  }

  ** Coerce value to a float from 0.0 to 1.0
  static Float? percent(Obj? val, Float? def := null)
  {
    if (val != null)
    {
      if (val is Float) return ((Float)val).min(1.0f).max(0.0f)
      if (val is Number) { n := (Number)val; return n.unit == Number.percent ? percent(n.toFloat / 100f) : percent(n.toFloat) }
      if (val is Str) return val.toStr == "auto" ? null : percent(Number.fromStr(val, false), def)
    }
    return def
  }

  ** Coerce value to an uri
  static Uri? uri(Obj? val, Uri? def := null)
  {
    if (val != null)
    {
      if (val is Uri) return val
      if (val is Str) return val.toStr.toUri
    }
    return def
  }

  ** Coerce value to enumeration
  static Enum? enum(Enum[] vals, Obj? val, Enum? def := null)
  {
    if (val != null)
    {
      if (val.typeof === vals[0].typeof) return val
      if (val is Str)
      {
        x := vals.find { it.name == val }
        if (x != null) return x
      }
    }
    return def
  }

  ** Coerce value low level RGB color
  @NoDoc static Color? rgb(Obj? val, Color? def := null)
  {
    if (val != null)
    {
      if (val is Color) return val
      if (val is Str) { x := Color.fromStr(val.toStr, false); if (x != null) return x }
    }
    return def
  }

  ** Coerce value to palette color name
  static ColorName? colorName(Obj? val, ColorName? def := null)
  {
    if (val != null)
    {
      if (val is ColorName) return val
      if (val is Str) return ColorName.fromStr(val.toStr, false) ?: def
    }
    return def
  }

  ** Coerce value to format
  static Format? format(Obj? val, Format? def := null)
  {
    if (val != null)
    {
      if (val is Format) return val
      if (val is Str) return Format.fromStr(val.toStr)
    }
    return def
  }

  ** Coerce value to ref
  static Ref? ref(Obj? val, Ref? def := null)
  {
    if (val != null)
    {
      if (val is Ref) return val
      if (val is List) return ref(((List)val).first, def)
      if (val is Str) return Ref(val.toStr)
    }
    return def
  }

  ** Coerce value to list of refs
  static Ref[]? refs(Obj? val, Ref[]? def := null)
  {
    if (val != null)
    {
      if (val is Ref) return Ref[val]
      if (val is List) return ((List)val).map |x->Ref| { ref(x, null) }
    }
    return def
  }

//////////////////////////////////////////////////////////////////////////
// Data Coercion
//////////////////////////////////////////////////////////////////////////

  ** Coerce view data to string value
  static Str? dataToStr(Obj? x)
  {
    if (x == null) return null
    if (x is Str) return x
    if (x is Grid) return Etc.gridToStrVal(x)
    return x.toStr
  }

  ** Coerce view data to list value
  static Obj?[]? dataToList(Obj? x)
  {
    if (x == null) return null
    if (x is List) return x
    if (x is Grid) return ((Grid)x).toRows
    if (x is Dict) return dictToList(x)
    throw Err("Invalid list data: $x [$x.typeof]")
  }

  ** Convert dict to list using auto names only
  static Obj?[]? dictToList(Dict x)
  {
    vals := Obj[,]
    x.each |v, n| { if (n[0] == '_') vals.add(v) }
    return vals
  }

  ** Coerce view data to Dict value
  static Dict? dataToDict(Obj? x)
  {
    if (x == null) return null
    if (x is Dict) return x
    if (x is Grid) return ((Grid)x).first ?: throw Err("Empty grid")
    if (x is Item) return ((Item)x).data
    throw Err("Invalid dict data: $x [$x.typeof]")
  }

  ** Coerce view data to Grid
  static Grid? dataToGrid(Obj? x)
  {
    if (x == null) return null
    if (x is Grid) return x
    c := x as ItemCollection
    if (c != null && c.isGrid) return c.grid
    throw Err("Invalid grid data: $x [${x?.typeof}]")
  }

  ** Coerce view data to ItemList
  static ItemList? dataToItemList(Obj? x)
  {
    if (x == null) return null
    if (x is ItemList) return x
    if (x is ItemCollection) return ItemList(((ItemCollection)x).list)
    return ItemList(dataToList(x).map |i->Item| { Item(i) })
  }

  ** Coerce view data to ItemCollection
  static ItemCollection dataToItemCollection(Obj? x)
  {
    if (x == null) return ItemList.empty
    if (x is ItemCollection) return x
    if (x is Grid) return PiEnv.cur.itemGrid(x)
    return ItemList(dataToList(x).map |i->Item| { Item(i) })
  }

  ** Coerce view data to Ref:Ref
  static Ref:Ref dataToIdMap(Obj? x)
  {
    acc := Ref:Ref[:]
    if (x == null) return acc
    if (x is Dict)
    {
      dataToIdMapAdd(acc, ((Dict)x).get("id"))
      return acc
    }
    if (x is Grid)
    {
      ((Grid)x).each |row| { dataToIdMapAdd(acc, row["id"]) }
      return acc
    }
    if (x is ItemCollection)
    {
      ((ItemCollection)x).list.each |item| { dataToIdMapAdd(acc, item.id) }
      return acc
    }
    return acc
  }
  private static Void dataToIdMapAdd(Ref:Ref acc, Ref? id) { if (id != null) acc[id] = id }

}

