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
** ScheduleObservable is an observable data stream for scheduled events.
**
@NoDoc
const class ScheduleObservable : Observable
{
  override Str name() { "obsSchedule" }

  override Subscription onSubscribe(Observer observer, Dict config)
  {
    ScheduleSubscription(this, observer, config)
  }

  Void check(DateTime nowTime)
  {
    subs := subscriptions
    if (subs.isEmpty) return
    nowTicks := Duration.nowTicks
    msg := MObservation(this, nowTime, Etc.emptyDict)
    subs.each |sub| { checkSubscription(sub, nowTime, nowTicks, msg) }
  }

  private Void checkSubscription(ScheduleSubscription sub, DateTime nowTime, Int nowTicks, Observation msg)
  {
    // skip if an inactive date
    if (!sub.isActive(nowTime)) return

    // skip if we already have messages enqueued
    if (sub.observer.actor.queueSize > 0) return

    // check frequency based subs
    if (sub.freq != null)
    {
      elapsed := nowTicks - sub.lastTicks.val
      if (elapsed >= sub.freq.ticks)
        fire(sub, nowTime, nowTicks, msg)
      return
    }

    // check times of day
    if (sub.times != null)
    {
      lastTime := toLastTime(sub, nowTime)
      ready := sub.times.find |t| { lastTime <= t && t <= nowTime.time }
      if (ready != null)
        fire(sub, nowTime, nowTicks, msg)
      return
    }
  }

  private Time toLastTime(ScheduleSubscription sub, DateTime nowTime)
  {
    // get last DateTime we ran
    last := sub.lastTime.val as DateTime

    // if we haven't run yet, default to now
    if (last == null) sub.lastTime.val = last = nowTime

    // if day has rolled over, then assume midnight
    if (nowTime.day != last.day) return Time.defVal

    // return last time we ran today
    return last.time
  }

  private Void fire(ScheduleSubscription sub, DateTime nowTime, Int nowTicks, Observation msg)
  {
    sub.lastTime.val = nowTime
    sub.lastTicks.val = nowTicks
    sub.send(msg)
  }
}

**************************************************************************
** ScheduleSubscription
**************************************************************************

internal const class ScheduleSubscription : Subscription
{
  new make(ScheduleObservable observable, Observer observer, Dict config)
    : super(observable, observer, config)
  {
    // times
    freq  = parseFreq(config)
    times = parseTimes(config)

    // days
    span = parseSpan(config)
    daysOfWeek = parseDaysOfWeek(config)
    daysOfMonth = parseDaysOfMonth(config)

    // sanity
    if (freq == null && times == null) throw Err("Must define either obsScheduleFreq or obsScheduleTimes")
    if (freq != null && times != null) throw Err("Cannot define both obsScheduleFreq and obsScheduleTimes")
  }

  static Duration? parseFreq(Dict config)
  {
    val := config["obsScheduleFreq"]
    if (val == null) return null
    dur := (val as Number)?.toDuration(false) ?: throw Err("obsScheduleFreq must be duration")
    if (dur < 1sec) throw Err("obsScheduleFreq cannot be less than 1sec")
    return dur
  }

  static Time[]? parseTimes(Dict config)
  {
    val := config["obsScheduleTimes"]
    if (val == null) return null
    Time[]? times := null
    try
      times = ((List)val).map |item->Time| { item }.sort
    catch (Err e)
      throw Err("obsScheduleTimes must be list of times")
    if (times.isEmpty) return null
    return times
  }

  static Span? parseSpan(Dict config)
  {
    val := config["obsScheduleSpan"]
    if (val == null) return null
    return val as Span ?: throw Err("obsScheduleSpan must be Span")
  }

  static Weekday[]? parseDaysOfWeek(Dict config)
  {
    val := config["obsScheduleDaysOfWeek"]
    if (val == null || val.toStr.isEmpty) return null
    Weekday[]? weekdays
    try
      weekdays = ((Str)val).split(',').map |s->Weekday| { Weekday.fromStr(s) }
    catch (Err e)
      throw Err("obsScheduleDaysOfWeek must be comma separated list of weekdays")
    if (weekdays.isEmpty) return null
    weekdays.sort
    return weekdays
  }

  static Int[]? parseDaysOfMonth(Dict config)
  {
    val := config["obsScheduleDaysOfMonth"]
    if (val == null || val.toStr.isEmpty) return null
    Int[]? days
    try
      days = ((Str)val).split(',').map |s->Int| { Int.fromStr(s) }
    catch (Err e)
      throw Err("obsScheduleDaysOfMonth must be comma separated list of integers")
    if (days.isEmpty) return null
    days.each |d| { if (d > 31 || d < -31 || d == 0) throw Err("obsScheduleDaysOfMonth invalid day: $d") }
    days.sort
    return days
  }

  const AtomicRef lastTime := AtomicRef()
  const AtomicInt lastTicks := AtomicInt()
  const Duration? freq
  const Time[]? times
  const AtomicBool[]? timesFired
  const Span? span
  const Int[]? daysOfMonth
  const Weekday[]? daysOfWeek

  Bool isActive(DateTime ts)
  {
    isActiveSpan(ts) && isActiveDaysOfWeek(ts) && isActiveDaysOfMonth(ts)
  }

  Bool isActiveSpan(DateTime ts)
  {
    if (span == null) return true
    return span.contains(ts)
  }

  Bool isActiveDaysOfWeek(DateTime ts)
  {
    if (daysOfWeek == null) return true
    return daysOfWeek.any |weekday| { ts.weekday === weekday }
  }

  Bool isActiveDaysOfMonth(DateTime ts)
  {
    if (daysOfMonth == null) return true
    return daysOfMonth.any |day|
    {
      day > 0 ? ts.day == day : ts.day == ts.month.numDays(ts.year)+day+1
    }
  }
}


