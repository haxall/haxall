//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2010  Brian Frank  Creation
//

using xml
using obix
using haystack

**
** ObixUtil is used to map between oBIX and Haystack data types
**
class ObixUtil
{

//////////////////////////////////////////////////////////////////////////
// ObixObj -> Haystack
//////////////////////////////////////////////////////////////////////////

  static Grid toGrid(ObixDispatch conn, ObixObj obj)
  {
    // obj to meta
    meta := toTags(obj)

    // children to rows
    rows := Str:Obj[,]
    obj.list.each |kid|
    {
      // check if we can skip this object outright
      //if (kid.href == null) return
      if (kid.elemName == "feed") return
      if (conn.isNiagara && kid.href != null && kid.href.toStr.startsWith("~")) return

      // map child to tags
      tags := toTags(kid)

      // add row
      rows.add(tags)
    }

    return Etc.makeMapsGrid(meta, rows)
  }

  static Str:Obj toTags(ObixObj obj)
  {
    tags := Str:Obj[:]
    hasVal := obj.val != null && !obj.isNull

    tags["elem"] = obj.elemName
    tags["status"] = obj.status.name
    if (obj.href != null)        tags["href"] = obj.href
    if (obj.name != null)        tags["name"] = obj.name
    if (obj.displayName != null) tags["dis"]  = obj.displayName
    if (obj.display != null)     tags["display"] = obj.display
    if (!obj.contract.isEmpty)   tags["is"]   = obj.contract.toStr
    if (hasVal)                  tags["val"]  = toVal(obj)
    if (obj.icon != null)        tags["icon"] = obj.icon
    if (obj.in != null)          tags["in"]   = obj.in.toStr
    if (obj.out != null)         tags["out"]  = obj.out.toStr

    return tags
  }

  ** Convert obix:HistoryQueryOut to HisItem[]
  static HisItem[] toHisItems(ObixObj res, TimeZone? tz)
  {
    // get data items
    list := res.get("data")
    if (list.size == 0) return HisItem[,]

    // check if list.of prototype has an explicit timestamp/unit
    Unit? unit := null
    if (tz == null && list.of != null)
    {
      res.each |kid|
      {
        if (kid.href == null) return
        if (!list.of.toStr.contains(kid.href.toStr)) return
        tz = kid.get("timestamp", false)?.tz
        unit = kid.get("value", false)?.unit
      }
    }

    // parse list into HisItems
    items := HisItem[,]
    items.capacity = list.size
    list.each |obj|
    {
      DateTime ts := obj.get("timestamp").val
      Obj? val := obj.get("value")?.val
      if (val is Num) val = Number.makeNum(val, unit)
      if (tz != null) ts = ts.toTimeZone(tz)
      items.add(HisItem(ts, val))
    }
    return items
  }

//////////////////////////////////////////////////////////////////////////
// Haystack -> ObixObj
//////////////////////////////////////////////////////////////////////////

  static ObixObj toObix(Obj? obj)
  {
    // handle null
    if (obj == null) return ObixObj { it.isNull = true }

    // Str or XML pass-thru
    str := obj as Str
    if (str != null)
    {
      if (str.startsWith("<") && str.endsWith(">"))
        return ObixObj.readXml(str.in)
      else
        return ObixObj { it.val = str }
    }

    // Number
    num := obj as Number
    if (num != null)
    {
      return ObixObj { it.val = num.toFloat; it.unit = num.unit }
    }

    // Bool, DateTime, Date, Time, Uri
    type := obj.typeof
    if (type === Bool# || type === DateTime# ||
        type === Date# || type === Time# ||
        type === Uri#)
     return ObixObj { it.val = obj }

    throw Err("Cannot map $obj.typeof to ObixObj")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static Obj? toChildVal(ObixObj obj, Str name, Obj? def := null)
  {
    child := obj.get(name, false)
    if (child != null && child.val != null) return toVal(child)
    return def
  }

  static Obj? toVal(ObixObj obj)
  {
    val := obj.val
    if (val is Num) return Number.makeNum(val, obj.unit)
    if (val is Duration) return Number.makeDuration(val)
    return val
  }

  static Str contractToDis(Contract contract)
  {
    contract.uris.join(",") |uri|
    {
      s := uri.toStr
      colon := s.indexr(":", -2)
      if (colon != null) s = s[colon+1..-1]
      return s
    }
  }

}