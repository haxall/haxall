//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Sep 2021  Brian Frank  Creation
//

using xeto
using haystack

**
** HisWriteObservation is an observation event for an 'obsHisWrites' stream.
**
@NoDoc
const class HisWriteObservation : Observation
{
  new make(Observable observable, DateTime ts, Ref id, Dict rec, Number count, Span span, Dict? user)
  {
    this.type  = observable.name
    this.ts    = ts
    this.id    = id
    this.rec   = rec
    this.count = count
    this.span  = span
    this.user  = user
  }

  const override Str type
  const override DateTime ts
  const override Ref id
  const Dict rec
  const Number count
  const Span span
  const Dict? user

  override Str? subType() { null }

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name)
  {
    switch (name)
    {
      case "type":  return type
      case "ts":    return ts
      case "id":    return id
      case "rec":   return rec
      case "count": return count
      case "span":  return span
      case "user":  return user
      default:      return null
    }
  }

  override Bool has(Str name) { get(name) != null }

  override Bool missing(Str name) { !has(name) }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    get(name) ?: throw UnknownNameErr(name)
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
    r = f(count, "count"); if (r != null) return r
    r = f(span,  "span");  if (r != null) return r
    if (user != null) r = f(user, "user"); if (r != null) return r
    return null
  }
}

