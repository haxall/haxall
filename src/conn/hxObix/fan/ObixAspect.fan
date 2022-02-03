//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Mar 2010  Brian Frank  Creation
//

using web
using obix
using haystack
using hx
using hxConn

**
** ObixAspect is used to enhance an ObixProxy to provide contract
** support such as 'obix:History'.
**
abstract const class ObixAspect
{
  static const ObixAspect point    := ObixPointAspect()
  static const ObixAspect writable := ObixWritableAspect()
  static const ObixAspect history  := ObixHistoryAspect()

  static Contract toContract(Dict rec)
  {
    aspects := toAspects(rec)
    Uri[] uris := aspects.map |a->Uri| { a.contract }
    rec.each |v, n| { if (v === Marker.val) uris.add(`tag:$n`) }
    if (uris.isEmpty) return Contract.empty
    return Contract(uris)
  }

  static ObixAspect[] toAspects(Dict rec)
  {
    acc := ObixAspect[,]
    if (rec.has("point")) acc.add(point)
    if (rec["obixWritable"] is Number) acc.add(writable)
    if (rec.has("his")) acc.add(history)
    return acc
  }

  abstract Uri contract()

  abstract ObixProxy? get(ObixRec parent, Str name)

  abstract Void read(ObixRec parent, ObixObj obj)

}

**************************************************************************
** ObixPointAspect
**************************************************************************

const class ObixPointAspect : ObixAspect
{
  override Uri contract() { `obix:Point` }

  override ObixProxy? get(ObixRec parent, Str name) { null }

  override Void read(ObixRec parent, ObixObj obj)
  {
    rec := parent.rec
    val := rec["curVal"]
    if (val is Number)
    {
      num := (Number)val
      obj.val  = num.toFloat
      obj.unit = num.unit
    }
    else
    {
      if (val != null) obj.val = val
    }

    curStatus := ConnStatus.fromStr(rec["curStatus"] as Str ?: "ok", false)
    if (curStatus != null)
    {
      if (curStatus.isRemote) curStatus = curStatus.remoteToLocal
      obj.status = Status.fromStr(curStatus.name, false) ?: Status.ok
    }
  }
}

**************************************************************************
** ObixWritableAspect
**************************************************************************

const class ObixWritableAspect : ObixAspect
{
  override Uri contract() { `obix:WritablePoint` }

  override ObixProxy? get(ObixRec parent, Str name)
  {
    switch (name)
    {
      case "writePoint": return ObixWritableOp(parent)
      default: return null
    }
  }

  override Void read(ObixRec parent, ObixObj obj)
  {
    obj.add(ObixObj
    {
      elemName = "op"
      name     = "writePoint"
      href     = `writePoint`
      in       = Contract.writePointIn
      out      = Contract.point
    })
  }

}

class ObixWritableOp : ObixProxy
{
  new make(ObixRec parent) : super(parent, "writePoint") { rec = parent.rec }

  const Dict rec

  override ObixObj read()
  {
    ObixObj
    {
      elemName = "op"
      name     = "writePoint"
      href     = absBaseUri
      in       = Contract.writePointIn
      out      = Contract.point
    }
  }

  override ObixObj invoke(ObixObj arg)
  {
    // obixWritable must be 1-16 level
    level:= rec["obixWritable"] as Number
    if (level == null) throw Err("Missing obixWritable Number tag")

    // get the value
    val := ObixUtil.toVal(arg.get("value"))

    // write the point
    rt.pointWrite.write(rec, val, level.toInt, "oBIX client").get(10sec)
    return ObixObj()
  }
}

**************************************************************************
** ObixHistoryAspect
**************************************************************************

const class ObixHistoryAspect : ObixAspect
{
  override Uri contract() { `obix:History` }

  override ObixProxy? get(ObixRec parent, Str name)
  {
    switch (name)
    {
      case "query": return ObixHistoryQuery(parent)
      default: return null
    }
  }

  override Void read(ObixRec parent, ObixObj obj)
  {
    rec := parent.rec

    // build-in fields
    hisSize  := rec["hisSize"] as Number ?: Number.zero
    obj.add(ObixObj { name = "count"; elemName = "int";     val = hisSize.toInt })
    obj.add(ObixObj { name = "start"; elemName = "abstime"; val = rec["hisStart"] })
    obj.add(ObixObj { name = "end";   elemName = "abstime"; val = rec["hisEnd"] })

    // use fullName for tz
    tzName := rec["tz"]
    if (tzName != null)
    {
      tz := TimeZone.fromStr(tzName, false)
      if (tz != null) obj.add(ObixObj { name = "tz"; val = tz.fullName })
    }

    // query
    obj.add(ObixObj
    {
      elemName = "op"
      name     = "query"
      href     = `query`
      in       = Contract.historyFilter
      out      = Contract.historyQueryOut
    })
  }
}

class ObixHistoryQuery : ObixProxy
{
  new make(ObixRec parent) : super(parent, "query") {}

  override ObixObj read()
  {
    ObixObj
    {
      elemName = "op"
      name     = "query"
      href     = absBaseUri
      in       = Contract.historyFilter
      out      = Contract.historyQueryOut
    }
  }

  override ObixObj invoke(ObixObj arg)
  {
    // parse HistoryFilter arg
    DateTime? start := arg.get("start", false)?.val
    DateTime? end   := arg.get("end", false)?.val
    Int limit       := arg.get("limit", false)?.val ?: Int.maxVal

    // normalize tz
    rec := ((ObixRec)parent).rec
    tz := TimeZone.fromStr(rec->tz)
    if (start != null) start = start.toTimeZone(tz)
    if (end   != null) end   = end.toTimeZone(tz)

    // map to span
    Span? span
    if (start == null && end == null)
      span = null
    else if (start != null && end != null)
      span = Span(start, end)
    else
      throw Err("Partial null span not supported")

    // perform query and build up result
    count := 0
    data := ObixObj { name = "data"; elemName = "list"; of = Contract([`#RecordProto`, `obix:HistoryRecord`]) }
    rt.his.read(rec, span, null) |item|
    {
      if (count >= limit) return
      ++count
      itemVal := item.val
      if (itemVal  is Number) itemVal = ((Number)itemVal).toFloat
      data.add(ObixObj
      {
        ObixObj { name = "timestamp"; val = item.ts; it.tz = null },
        ObixObj { name = "value";     val = itemVal },
      })
    }

    // build prototype object
    proto := ObixObj
    {
      name = "proto"
      href = `#RecordProto`
      contract = Contract([`obix:History`])
      ObixObj { name = "timestamp"; elemName = "abstime"; it.tz = tz },
    }
    unit := Unit.fromStr(rec["unit"] ?: "", false)
    if (unit != null)
    {
      valElemName := data.first?.get("value")?.elemName ?: "obj"
      proto.add(ObixObj{ name = "value"; elemName = valElemName; it.unit = unit })
    }

    // return HistoryQueryOut result
    return ObixObj
    {
      contract = Contract([`obix:HistoryQueryOut`])
      ObixObj { name = "count"; val = count },
      ObixObj { name = "start"; elemName = "abstime"; val = start },
      ObixObj { name = "end";   elemName = "abstime"; val = end   },
      proto,
      data,
    }
  }

}