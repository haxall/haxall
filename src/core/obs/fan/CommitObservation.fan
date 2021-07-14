//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2021  Brian Frank  Creation
//

using haystack

**
** CommitObservation is an observation event for an 'obsCommit' stream.
**
@NoDoc
const class CommitObservation : Observation
{
  new make(Observable observable, CommitObservationAction action, DateTime ts, Ref id, Dict oldRec, Dict newRec, Dict? user)
  {
    this.type    = observable.name
    this.subType = action.name
    this.ts      = ts
    this.action  = action
    this.id      = id
    this.oldRec  = oldRec
    this.newRec  = newRec
    this.user    = user
  }

  const override Str type
  const override Str? subType
  const override DateTime ts
  const override Ref id
  const CommitObservationAction action
  const Dict newRec
  const Dict oldRec
  const Dict? user

  Bool isAdded() { action === CommitObservationAction.added }
  Bool isUpdated() { action === CommitObservationAction.updated }
  Bool isRemoved() { action === CommitObservationAction.removed }

  ** Return if either new or old includes given tag
  Bool recHas(Str tag) { oldRec.has(tag) || newRec.has(tag) }

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name, Obj? def := null)
  {
    switch (name)
    {
      case "type":    return type
      case "subType": return subType
      case "ts":      return ts
      case "id":      return id
      case "newRec":  return newRec
      case "oldRec":  return oldRec
      case "user":    return user ?: def
      default:        return def
    }
  }

  override Bool has(Str name) { get(name) != null }

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
    r = f(type,    "type");    if (r != null) return r
    r = f(subType, "subType"); if (r != null) return r
    r = f(ts,      "ts");      if (r != null) return r
    r = f(id,      "id");      if (r != null) return r
    r = f(newRec,  "newRec");  if (r != null) return r
    r = f(oldRec,  "oldRec");  if (r != null) return r
    if (user != null) r = f(user, "user"); if (r != null) return r
    return null
  }
}

**************************************************************************
** CommitObservationAction
**************************************************************************

@NoDoc
enum class CommitObservationAction
{
  added,
  updated,
  removed
}


