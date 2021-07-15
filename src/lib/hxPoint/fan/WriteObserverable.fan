//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jul 2021  Brian Frank  Creation
//

using concurrent
using haystack
using folio
using obs

**
** WriteObservable
**
internal const class WriteObservable : Observable
{
  override Str name() { "obsPointWrite" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    WriteSubscription(this, observer, config)
  }
}

**************************************************************************
** WriteSubscription
**************************************************************************

internal const class WriteSubscription : Subscription
{
  new make(WriteObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
    includeArray = config.has("obsIncludeArray")
    filter       = parseFilter(config["obsFilter"])
  }

  private static Filter? parseFilter(Obj? val)
  {
    if (val == null) return null
    if (val isnot Str) throw Err("obsFilter must be filter string")
    try
      return Filter.fromStr(val)
    catch (Err e)
      throw Err("obsFilter invalid: $e")
  }

  const Bool includeArray
  const Filter? filter

  Bool include(Dict rec)
  {
    if (rec.isEmpty) return false
    if (filter == null) return true
    return filter.matches(rec)
  }
}

**************************************************************************
** WriteObservation
**************************************************************************

@NoDoc
const class WriteObservation : Observation
{
  new make(Observable observable, DateTime ts, Ref id, Dict rec, Obj? val, Number level, Obj? who, Grid? array)
  {
    this.type  = observable.name
    this.ts    = ts
    this.id    = id
    this.rec   = rec
    this.val   = val
    this.level = level
    this.who   = who
    this.array = array
  }

  const override Str type
  override Str? subType() { null }
  const override DateTime ts
  const override Ref id
  const Dict rec
  const Obj? val
  const Number level
  const Obj? who
  const Grid? array

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name, Obj? def := null)
  {
    switch (name)
    {
      case "type":    return type
      case "subType": return subType
      case "ts":      return ts
      case "id":      return id
      case "rec":     return rec
      case "val":     return val
      case "level":   return level
      case "who":     return who ?: def
      case "array":   return array ?: def
      default:        return def
    }
  }

  override Bool has(Str name) { get(name, null) != null }

  override Bool missing(Str name) { !has(name) }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    get(name, null) ?: throw UnknownNameErr(name)
  }

  override Void each(|Obj?, Str| f)
  {
    eachWhile |v, n| { f(v, n); return null }
  }

  override Obj? eachWhile(|Obj?, Str->Obj?| f)
  {
    Obj? r
    r = f(type,  "type");  if (r != null) return r
    r = f(ts,    "ts");    if (r != null) return r
    r = f(id,    "id");    if (r != null) return r
    r = f(rec,   "rec");   if (r != null) return r
    r = f(val,   "val");   if (r != null) return r
    r = f(level, "level"); if (r != null) return r
    if (who != null)   r = f(who,   "who");   if (r != null) return r
    if (array != null) r = f(array, "array"); if (r != null) return r
    return null
  }
}

