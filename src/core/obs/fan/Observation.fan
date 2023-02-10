//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2020  Brian Frank  COVID-19!
//

using haystack

**
** Observation is base class for all observable data items
**
** NOTE: this API is subject to change
**
const mixin Observation : Dict
{
  ** Type name which matches `Observable.name` and the def name
  abstract Str type()

  ** Subtype name if available which is specific to the observable type
  abstract Str? subType()

  ** Timestamp for the event
  abstract DateTime ts()
}

**************************************************************************
** MObservation
**************************************************************************

**
** MObservation is the default implementation
**
internal const class MObservation : Observation
{
  new make(Observable observable, DateTime ts, Dict more := Etc.emptyDict)
  {
    this.type = observable.name
    this.ts = ts
    this.more = more
  }

  override const Str type

  override const DateTime ts

  override Str? subType() { more["subType"] }

  const Dict more

  override Int compare(Obj that) { ts <=> ((Dict)that).get("ts") }

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name, Obj? def := null)
  {
    if (name == "type") return type
    if (name == "ts")   return ts
    return more.get(name, def)
  }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    get(name) ?: throw UnknownNameErr(name)
  }

  override Bool has(Str name) { name == "ts" || name == "type" || more.has(name) }

  override Bool missing(Str name) { !has(name) }

  override Void each(|Obj, Str| f)  { f(ts, "ts"); f(type, "type"); more.each(f) }

  override Obj? eachWhile(|Obj, Str->Obj?| f)
  {
    Obj? r
    r = f(type, "type"); if (r != null) return r
    r = f(ts, "ts");     if (r != null) return r
    return more.eachWhile(f)
  }

  override Str toStr()
  {
    type.toStr + " @ " + ts.toLocale("hh:mm:ss")
  }
}


