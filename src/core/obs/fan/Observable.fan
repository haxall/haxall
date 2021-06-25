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
** Observable is the subject of an asynchronous data stream.
**
@NoDoc
abstract const class Observable
{
  ** Return the name of this observable.
  ** This name must match up with the the 'observe' def subtype name
  abstract Str name()

  ** Does this observer have any active subscriptions
  Bool hasSubscriptions() { !subscriptions.isEmpty }

  ** List the active subscriptions
  Subscription[] subscriptions() { subscriptionsRef.val }
  private const AtomicRef subscriptionsRef := AtomicRef(Subscription#.emptyList)

  ** Subscribe an observer actor to this this observables data stream
  Subscription subscribe(Observer observer, Dict config)
  {
    s := onSubscribe(observer, config)
    while (true)
    {
      oldList := subscriptions
      newList := oldList.dup.add(s).toImmutable
      if (subscriptionsRef.compareAndSet(oldList, newList)) break
    }
    s.activeRef.val = true
    return s
  }

  ** Unsubscribe a current subscription
  Void unsubscribe(Subscription s)
  {
    while (true)
    {
      oldList := subscriptions
      i := oldList.indexSame(s) ?: throw UnknownSubscriptionErr("Not my subscription")
      newList := oldList.dup
      newList.removeAt(i)
      newList = newList.toImmutable
      if (subscriptionsRef.compareAndSet(oldList, newList)) break
    }
    s.activeRef.val = false
  }

  ** Unsubscribe all subscriptions
  Void unsubscribeAll()
  {
    subscriptions.each |s| { s.activeRef.val = false }
    subscriptionsRef.val = Subscription#.emptyList
  }

  ** Callback when new observer is subscribing.  Subclasses can
  ** check the config and return their own subscription subclass.
  protected virtual Subscription onSubscribe(Observer observer, Dict config)
  {
    Subscription(this, observer, config)
  }

  ** Make the default implementation of an observation event
  Observation makeObservation(DateTime ts := DateTime.now, Dict more := Etc.emptyDict)
  {
    MObservation(this, ts, more)
  }
}

