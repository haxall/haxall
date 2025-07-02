//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jul 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using obs

**
** WriteObservable observes effective changes to a writable point's output
**
internal const class WriteObservable : Observable
{
  override Str name() { "obsPointWrites" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    WriteSubscription(this, observer, config)
  }
}

**************************************************************************
** WriteSubscription
**************************************************************************

internal const class WriteSubscription : RecSubscription
{
  new make(WriteObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
    // this is undocumented backdoor hook - it observes all writes,
    // not just the effective level changes.  Don't use it unless
    // you have to because it will fire a lot more events
    isAllWrites = config.has("obsAllWrites")
  }

  const Bool isAllWrites
}

**************************************************************************
** WriteObservation
**************************************************************************

@NoDoc
const class WriteObservation : Observation
{
  new make(Observable observable, DateTime ts, Ref id, Dict rec, Obj? val, Number level, Obj who, Dict? opts, Bool first)
  {
    this.type  = observable.name
    this.ts    = ts
    this.id    = id
    this.rec   = rec
    this.val   = val
    this.level = level
    this.who   = who
    this.opts  = opts
    this.first = Marker.fromBool(first)
  }

  const override Str type
  override Str? subType() { null }
  const override DateTime ts
  const override Ref id
  const Dict rec
  const Obj? val
  const Number level
  const Obj who
  const Dict? opts
  const Marker? first

  Bool isFirst() { first != null }

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
      case "who":     return who
      case "opts":    return opts
      case "first":   return first
      default:        return def
    }
  }

  override Bool has(Str name) { get(name, null) != null }

  override Bool missing(Str name) { !has(name) }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    get(name, null) ?: throw UnknownNameErr(name)
  }

  override Void each(|Obj, Str| f)
  {
    eachWhile |v, n| { f(v, n); return null }
  }

  override Obj? eachWhile(|Obj, Str->Obj?| f)
  {
    Obj? r
    r = f(type,  "type");  if (r != null) return r
    r = f(ts,    "ts");    if (r != null) return r
    r = f(id,    "id");    if (r != null) return r
    r = f(rec,   "rec");   if (r != null) return r
    r = f(level, "level"); if (r != null) return r
    r = f(who,   "who");   if (r != null) return r
    if (val != null)   r = f(val,   "val");   if (r != null) return r
    if (opts != null)  r = f(who,   "opts");  if (r != null) return r
    if (first != null) r = f(first, "first"); if (r != null) return r
    return null
  }
}

