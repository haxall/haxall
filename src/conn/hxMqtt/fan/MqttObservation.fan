//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   05 Jan 2022  Matthew Giannini  Creation
//

using haystack
using obs
using mqtt

**
** MqttObservation is an observation event for an 'obsMqtt' stream
**
@NoDoc
const class MqttObservation : Observation
{
  new make(Observable observable, Str topic, Message msg)
  {
    this.type    = observable.name
    this.ts      = DateTime.now
    this.topic   = topic
    this.payload = msg.payload
  }

  const override Str type
  const override DateTime ts
  const Str topic
  const Buf payload

  override Str? subType() { null }

  override Bool isEmpty() { false }

  @Operator override Obj? get(Str name, Obj? def := null)
  {
    switch (name)
    {
      case "type":    return type
      case "ts":      return ts
      case "topic":   return topic
      case "payload": return payload
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
    r = f(type, "type");       if (r != null) return r
    r = f(ts, "ts");           if (r != null) return r
    r = f(topic, "topic");     if (r != null) return r
    r = f(payload, "payload"); if (r != null) return r
    return null
  }
}