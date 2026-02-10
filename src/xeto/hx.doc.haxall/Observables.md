<!--
title:      Observables
author:     Brian Frank
created:    17 Apr 2020
copyright:  Copyright (c) 2020, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
The observable subsystem provides a framework for processing
asynchronous data streams.  An *observable* is a named data source which
produces an unbounded stream of Dict data items called *observations*.
An *observer* is a data consumer which subscribes to an observable's data
stream.  A *subscription* is the binding between an observable and an
observer.  All observers process their data items asynchronously on a background
thread using an [Actor](fan.doc.lang::Actors).

All observers are named with a marker def.  The following are
the built-in [observables](hx.obs::Observable):
  - [obsSchedule](#schedule): observe scheduled events
  - [obsCommits](#commits): observe commits to the Folio database
  - [obsWatches](#watches): observe watch status of records
  - [obsCurVals](#cur-vals): observe transient commits to curVal and curStatus
  - [obsHisWrites](#his-writes): observe writes to the historian
  - [obsPointWrites](#point-writes): observe updates to a writable point

The following are SkySpark only observables:
  - [obsArcs](#arcs): observe when arc documents are created or modified
  - [obsSparks](#sparks): observe when new sparks are detected
  - [obsEvents](#events): observe when event dicts are created

There are two mechanisms to setup observers:
  - [Tasks](#task-observe): Axon observers use the task extension
  - [Fantom](#fantom-observe): Fantom observers use the [fan.hx::Ext.observe] method

# Observations
The data items produced by an observable are called *observations*.  All
the built-in observables model their observations as a Dict.  The tags
used in the observations are specific to the observable.  However all
observations have the following standard tags:
  - `type`: Str name of the observable
  - `ts`: DateTime in the host's timezone when observation generated

# Task Observe
A tasks managed by the [task ext](hx.task::doc#subscriptions) can
subscribe to an observable using tags.  Tasks subscribe to a specific
observable by applying the appropiate marker tag and its associated
configuration tags.

# Fantom Observe
HxLibs written in Fantom may use the [fan.hx::Ext.observe] method to subscribe
to an observable.  The subscription should happen in the `onStart` callback.
The system will automatically handle the unsubscribe if the lib is uninstalled.

Example code:

    const class AcmeLib : HxLib
    {
      override Void onStart()
      {
        config := Etc.makeDict1("obsScheduleFreq", Number(5, Unit("sec")))
        observe("obsSchedule", config, #onSchedule)
      }

      Void onSchedule(Dict msg)
      {
        log.info("onSchedule: $msg")
      }
    }

# Observables
The following sections detail the built-in observables.  Each observable
defines a custom set of tags used in its observation dicts.  Each observable
also defines a set of configuration tags used to tune subscriptions.

## Schedule
The [hx.obs::Observable.obsSchedule] observable fires an event periodically based on a configurable
schedule.

Schedule observations (events) include only the standard tags:
  - `type`: "obsSchedule"
  - `ts`: DateTime when schedule event generated

These are the time oriented config tags (use only one):
  - [hx.obs::Observable.obsScheduleFreq]: duration number to generate events at a fixed frequency.
    This configures a frequency between event generation which is
    independent of the observer's execution time.  For example a frequency
    of 10sec which takes 3sec to process each event will run every 10sec,
    not every 13sec.
  - [hx.obs::Observable.obsScheduleTimes]: a list of one or more Time values to generate events
    at a time of the day based on the host's default timezone.

These are the date oriented config tags:
  - [hx.obs::Observable.obsScheduleSpan]: a Span XStr which defines the inclusive date range
  - [hx.obs::Observable.obsScheduleDaysOfWeek]: a Str formatted as a comma separated list of
    weekdays: sun, mon, tue, wed, thu, fri, sat
  - [hx.obs::Observable.obsScheduleDaysOfMonth]: a Str formatted as a comma separated list of
    integer days of the month.  Negative days are used to index from the
    last day of the month.  For example -1 indicates last day of the month, -2
    the second to last day, etc.

You must define exactly one of the time oriented tags: `obsScheduleFreq` or `obsScheduleTimes`;
they cannot be used together.  The dates oriented config tags may be used
together as a logical AND.

Example configurations:

    // run every 5min every day
    obsScheduleFreq: 5min

    // run at midnight and at 2pm every day
    obsScheduleTimes: [00:00, 14:00]

    // run at 2am on weekdays only
    obsScheduleTimes: [02:00]
    obsScheduleDaysOfWeekdays: "mon,tue,wed,thu,fri"

    // run at 2am on 1st and 15th of the month
    obsScheduleTimes: [02:00]
    obsScheduleDaysOfMonth: "1, 15"

    // run at 2am on last day of the month
    obsScheduleTimes: [02:00]
    obsScheduleDaysOfMonth: "-1"

    // run at 2am on first Monday of the month
    obsScheduleTimes: [02:00]
    obsScheduleDaysOfWeekdays: "mon"
    obsScheduleDaysOfMonth: "1,2,3,4,5,6,7"

Schedule observations are suppressed if the observer actor already has
messages in its queue.  This prevents scheduled events from queuing up
if the observer is not processing its messages fast enough.

## Commits
The [hx.obs::Observable.obsCommits] observable is used to monitor changes to a set of records
in the [Folio] database.

Commit observations include the following tags:
  - `type`: "obsCommits"
  - `ts`: DateTime when commit finishes (not the same as the records mod tag)
  - `subType`: "added, "updated", "removed"
  - `id`: identifier ref of record
  - `oldRec`: old version of record dict or empty dict if added
  - `newRec`: new version of record dict or empty dict if removed
  - `user`: user dict for commit context or null if outside of a context

These are the config tags:
  - [hx.obs::Observable.obsFilter]: filter string for rec set to observe or omit for all recs
  - [hx.obs::Observable.obsAdds]: marker to listen for added events
  - [hx.obs::Observable.obsUpdates]: marker to listen for updated events
  - [hx.obs::Observable.obsRemoves]: marker to listen for removes events
  - [hx.obs::Observable.obsAddOnInit]: fires an add for observed record set on startup; must be
    used in conjunction with the obsFilter

You must specify at least one of `obsAdds`, `obsUpdates`, or `obsRemoves` (typically
you will use all three).  The observations are fired based on records entering
and exiting the configured filter set.  Adding the `trash` tag is treated the
same as removing the entire record.

Here is an example configuration which observes changes to records marked
with the `conn` tag:

    obsAdds
    obsUpdates
    obsRemoves
    obsFilter: "conn"

In the observer above, if we add the `conn` tag to an existing record
it will receive an "added" event (the same as if adding a new record with that
tag).  Likewise removing the `conn` tag or adding the `trash` tag will fire
the "removed" event.  Any non-transient diffs to a record with the `conn` tag
will fire an "updated" event.

## Watches
The [hx.obs::Observable.obsWatches] observable is used to listen for when records go into
and out of [watch](hx.doc.haxall::Watches).  The "watch" event provides a
list of recs that are entering the watched state (transition from zero
to at least one watch).  The "unwatch" event provides a list of recs that are
exiting the watched state (transition to zero watchers).

Watch observations include the following tags:
  - `type`: "obsWatches"
  - `ts`: DateTime for transition
  - `subType`: "watch or "unwatch"
  - `recs`: list of dict records entering or exiting the watched state

These are the config tags:
  - [hx.obs::Observable.obsFilter]: filter string for rec set to observe or omit for all recs

If an `obsFilter` is specified, then the initial list of matched recs which
are currently in watch is fired upon subscription.

## Cur Vals
The [hx.obs::Observable.obsCurVals] observable monitors transient commits to the [ph::PhEntity.curVal] or
[ph::PhEntity.curStatus] tag.  It enables creation of event based logic for [cur points](ph::CurPoint).

Observation events include the following tags (follows the exact same
pattern as obsCommit events):
  - `type`: "obsCurVals"
  - `ts`: DateTime for transient commit
  - `subType`: "updated"
  - `id`: identifier ref of record
  - `oldRec`: old version of record dict
  - `newRec`: new version of record dict

These are the config tags:
  - [hx.obs::Observable.obsFilter]: filter string for rec set to observe or omit for all recs

Note: exercise caution with this observable because it is easy to subscribe
to too much data.  As a general rule, you should never observe analog points
which might be changing with a high frequency.  But rather this observable
should only be used for boolean/enum change of state transitions.

## His Writes
The [hx.obs::Observable.obsHisWrites] observable listens for history data writes to
a [historized point](ph::HisPoint).

Observation events include the following tags:
  - `type`: "obsHisWrites"
  - `ts`: DateTime of the history write
  - `id`: identifier ref of record
  - `rec`: history rec dict
  - `count`: number of history items written
  - `span`: start and end timestamps of the items written as [fan.haystack::Span]
  - `user`: user dict for commit context or null if outside of a context

These are the config tags:
  - [hx.obs::Observable.obsFilter]: filter string for rec set to observe or omit for all recs

Note: only standard history writes with a defined span will trigger this
event.  Specialized updates such as [hisClear()] will not necessarily result
observations.

## Point Writes
The [hx.obs::Observable.obsPointWrites] observable monitors updates to the priority array
of [writable points](ph::WritablePoint).  An event is fired only when the *effective*
write value is modified (at the winning level).

Observation events include the following tags:
  - `type`: "obsPointWrites"
  - `ts`: DateTime of the point write
  - `id`: identifier ref of record
  - `rec`: point rec dict
  - `val`: effective write value
  - `level`: effective write level
  - `who`: string for user or application which issued the write
  - `first`: marker tag if this is the initial steady state write

These are the config tags:
  - [hx.obs::Observable.obsFilter]: filter string for rec set to observe or omit for all recs

## Arcs
The [hx.obs::Observable.obsArcs] observable listens for document changes managed by
the [arc lib](hx.arc::doc).

Sparks observations include the following tags:
  - `type`: "obsArcs"
  - `ts`: DateTime of the event
  - `arc`: Grid with the document - see [arcRead()] for format

These are the config tags:
  - [hx.obs::Observable.obsFilter]: filter string for rec set to observe or omit for all recs

## Sparks
The [hx.obs::Observable.obsSparks] observable listens for new sparks generated today by
the [rule engine](hx.rule::doc).  It is designed to allow an immediate
notification as soon as a new spark is detected.

Sparks observations include the following tags:
  - `type`: "obsSparks"
  - `ts`: DateTime when spark detected
  - `spark`: Dict of spark

These are the config tags:
  - [hx.obs::Observable.obsRuleFilter]: filter string for rule records
  - [hx.obs::Observable.obsTargetFilter]: filter string for target records

Only sparks detected *today* are observed (based on host's timezone). A spark
for a given target and rule is only observed once per day.  However if the
system restarts, then sparks will be re-observed when the rule engine runs again.
You can force re-observation via the [ruleReobserve()] function.

## Events
The [hx.obs::Observable.obsEvents] observable listens for new events generated by
the [event engine](hx.event::doc).

Event observations include the following tags:
  - `type`: "obsEvents"
  - `ts`: DateTime when event is created (might be different than event ts)
  - `event`: Dict of event

These are the config tags:
  - [hx.obs::Observable.obsFilter]: filter string for events to observe or omit for all events
