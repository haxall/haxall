//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2020  Brian Frank  COVID-19!
//

using concurrent
using haystack

**
** Subscription models an Observable to Observer binding
**
** NOTE: this API is subject to change
**
const class Subscription
{
  ** Constructor
  new make(Observable observable, Observer observer, Dict config)
  {
    this.observable = observable
    this.observer   = observer
    this.config     = config
  }

  ** Observable producing data items
  const Observable observable

  ** Subscribed observer consuming data items
  const Observer observer

  ** Configuration options for subscription
  const Dict config

  ** Debug string for config
  Str configDebug()
  {
    s := StrBuf().add("{")
    Etc.dictNames(config).each |n|
    {
      if (!n.startsWith("obs") || n == observable.name) return
      v := config[n]
      if (s.size > 1) s.add(", ")
      s.add(n)
      if (v == Marker.val) return
      s.addChar(':').add(Etc.valToDis(v))
    }
    s.add("}")
    return s.toStr
  }

  ** Return if this subscription is still active
  Bool isSubscribed() { activeRef.val }

  ** Return if this subscription has been cancelled
  Bool isUnsubscribed() { !activeRef.val }

  ** Convenience for 'Observable.unsubscribe(this)'
  Void unsubscribe() { observable.unsubscribe(this) }

  ** Send observation message to observer actor
  Future send(Observation msg)
  {
    observer.actor.send(observer.toActorMsg(msg))
  }

  ** Send sync message to observer actor
  Future sync()
  {
    observer.actor.send(observer.toSyncMsg)
  }

  ** Debug string
  override final Str toStr()
  {
    s := observable.name
    if (isUnsubscribed) s += " (UNSUBSCRIBED)"
    return s
  }

  internal const AtomicBool activeRef := AtomicBool(false)
}

