<!--
title:      Connector Tuning
author:     Brian Frank
created:    4 Jul 2012
copyright:  Copyright (c) 2012, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
Connector tuning is the most important mechanism at your disposal to
manage system and network performance.  This chapter covers the tools
for debugging and tuning connectors:

  - Library level tuning via [settings](#settings)
  - Connector level tuning via [conn tags](#conn-tuning-tags)
  - Point level tuning via [connTuning](#conntuning)
  - Debugging via [details](#details)
  - Debugging via [tracing](#tracing)
  - Allocation of points into [poll buckets](#poll-buckets)

# Settings
All connectors support the following library level tuning options
via settings (tags on the library ext rec itself):

  - [connTuningRef](#conntuning): fallback for point tuning
  - [maxThreads](#maxthreads): thread pool size

## maxThreads
The connector framework is built using Fantom's [actor APIs](fan.doc.lang::Actors).
Each connector is itself an actor which executes on threads from a shared
thread pool.  By default each connector library is allocated a max thread pool size
of 100.  This means that at most 100 connectors of one type can concurrently do
processing.  If you have more than 100 connectors, this potentially could starve
connectors from access to required processing.  Applying the `maxThreads` tag to your
library's ext rec enables tuning of the thread pool size.  If you wish all
your connectors to have concurrent threads, then tune this value to match
your number of connectors.  However, sometimes it's prudent to balance the thread
pool size to avoid excessive CPU and memory usage because threads have significant
overhead.

# Conn Tuning Tags
All connector types support a default number of tuning options on each
connector using the following tags:

  - [connTuningRef](#conntuning): fallback for point tuning
  - [actorTimeout](#actortimeout): duration to wait for timeouts
  - [connLinger](#connlinger): time to linger open state
  - [connOpenRetryFreq](#connopenretryfreq): frequency to retry opens
  - [connPingFreq](#connpingfreq): frequency to force pings

Each of the tags is discusssed in more detail below.

## actorTimeout
The [actorTimeout] tag configures a duration for message timeouts.  This
determines how long to block on a synchronous message to the actor when the
connector is busy blocking on I/O or processing previous messages.  Its
most typically used by the [Conn.sendSync](fan.hxconn::Conn.sendSync) method
used by many libs for connector specific functionality such as [haystackReadAll()].

This timeout is also used for all socket timeouts for connectors
which use TCP (including all HTTP based connectors).  Specifically this timeout
is used to configure the [connectTimeout](fan.inet::SocketConfig.connectTimeout)
and [receiveTimeout](fan.inet::SocketConfig.receiveTimeout)  for the underlying TCP sockets.

The timeout defaults to 1min if not explicitly configured.

## connLinger
The [hx.conn::Conn.connLinger] tag configures a duration to linger open a connection.
For many connectors the open process can be expensive.  For example many
HTTP based protocols require several requests to authenticate and acquire
a session.  So depending on access patterns, a connector could potentially
thrash between the open and close state.  Lingering alleviates this situation
by keeping the connection open a little while before transitioning to the
close state.  For example, if you configure the connLinger timeout to be 1min
and then ping the connector, then the connector will be held open for a minute
before transitioning back to the close state.  The default is 30sec if not
configured.

## connOpenRetryFreq
The [hx.conn::Conn.connOpenRetryFreq] tag configurations a duration between open retries.
Some applications such as a watch or MQTT subscription require a connector to
be pinned open.  If the connector fails to open, then the system will automatically
retry to open the connection periodically using this frequency.  If not
configured the default is 10sec.

## connPingFreq
The [hx.conn::Conn.connPingFreq] tag configurations a duration between forced pings.  The
default behavior for connectors is to stay closed unless an application explicitly
forces them open.  If this tag is added to the connector then the framework
will automatically force a periodic ping.  It should be used when you wish
to monitor the status of connectivity, but don't have any watched points to
keep it open.

# ConnTuning
The primary mechanism to tune point behavior is via [hx.conn::ConnTuning.connTuning] configuration
records.  A connTuning record is used to store the following point level tuning
options:
  - [pollTime](#polltime): frequency to poll for curVal
  - [staleTime](#staletime): duration to transition curStatus to stale
  - [writeMinTime](#writemintime): used to throttle writes
  - [writeMaxTime](#writemaxtime): periodically issue rewrites
  - [writeOnOpen](#writeonopen): issue a write when connector opens
  - [writeOnStart](#writeonstart): issue a write on startup

There are also some connector specific options such as:
  - [bacnetCov]: enabled COV subscription
  - [bacnetCovLifetime]: lease lifetime for COV subscriptions

Every connector point is assigned to exactly one tuning configuration
via the [hx.conn::Conn.connTuningRef] tag.  This tag is searched in the following order:

  1. Point rec itself
  2. Point's connector rec
  3. Connector's ext rec
  4. Fallback to default tuning for connector type

Example:

    id: @fast-poll
    dis: "Fast Polling"
    connTuning
    pollTime: 1sec

    id: @slow-poll
    dis: "Slow Polling"
    connTuning
    pollTime: 30sec

    id: @conn
    dis:"Modbus Connector"
    conn
    modbusConn
    connTuningRef: @slow-poll

    dis:"Fast Poll Point"
    point
    modbusPoint
    modbusConnRef: @conn
    modbusCur: "reg1"
    connTuningRef: @fast-poll

    dis:"Slow Poll Point"
    point
    modbusConnRef
    modbusPointRef: @conn
    modbusCur: "reg2"

In the example above we have two different tuning records.  The Fast Poll Point
has an explicit connTuningRef to the fast poll configuration.  The Slow Poll Point
inherits the connector's connTuningRef.  In your own projects you can debug
the assigned connTuning with the [details](#details).

The following sections provide additional details on each of these point
level tuning tags.

## pollTime
The [pollTime] tag specifies a duration Number which is the frequency used
to poll a point for [ph::PhEntity.curVal].  This tag is only used for connectors which
use the buckets polling mode.  Connectors which use a COV subscription model
will ignore this value.  If unspecified the default is 10sec.

## staleTime
The [staleTime] tag specifies a duration Number used to transition a
point's [ph::PhEntity.curStatus] tag from "ok" to "stale".  It ensures that users and applications
are aware that data might not be fresh.  The transition to stale occurs
when all the following conditions are met:
  1. the point's `curStatus` is currently "ok"
  2. the point is **not** in a watch
  3. the last successful read exceeds the stale time

Note that we assume points in a watch are currently up-to-date even if their
last read time exceeds the stale time.  This is because change of value
subscriptions might not be calling `updateCurOk` continuously if no changes
are received.  If unspecified the default is 5min.

## writeMinTime
The [writeMinTime] tag specifies a duration Number used to throttle
the frequency of writes to the remote device.  For example if configured
to 5sec, then writes will be issued no faster than 5sec.  After a successful
write occurs, if any writes are attempted within that 5sec window then they
are queued as a pending write.  After 5sec has elapsed the last pending
write is issued to the connector's `onWrite` callback.  Note that
writeMinTime is only enforced after successful writes.  If the connector
reports a write failure, then writeMinTime is not enforced on subsequent
attempts.

## writeMaxTime
The [writeMaxTime] tag specifies a duration Number used to issue
periodic rewrites to the remote device.  For example if configured
to 10min, then if no successful writes have been issued after 10min
then a write is automatically scheduled to the connector's `onWrite`
callback.  The writeMaxTime does not go into effect until after
the project reaches [steady state](Runtime#steady-state).

## writeOnOpen
The [writeOnOpen] marker tag is applied to issue a write whenever
the connector transitions from closed to open.  This policy is typically
used when the remote device stores writes in RAM only and needs to be
re-written after reboots.

## writeOnStart
The [writeOnStart] marker tag is applied to issue a write when the
system starts up.  If omitted then the system suppresses the initial
priority array evaluation.

# Details
Both connector and connector points provide a plain text report for debugging
we call *details*.  You can query the details using the [connDetails()] function.
In SkySpark you can view the details using the context menu or the Connectors view.

## Connector Details
The connector details report contains the following sections:
  - Summary and configuration
  - Polling mode and polling bucket allocations
  - State variables managed by the framework (linger, poll times, etc)
  - Transient tags managed by the framework
  - Connector specific extra debug
  - Current actor message and threading details

## Point Details
The point details report contains the following sections:
  - Summary and configuration
  - Addressing information for fooCur, fooWrite, fooHis
  - Transient tags managed by the framework
  - Connector specific extra debug
  - Watches on the point
  - Current value state
  - Write state
  - History sync state
  - History collection state
  - Writable priority array

Only the applicable sections are included.

# Tracing
Connectors provide debug tracing which includes:
  - all dispatch actor messages
  - lifecycle transitions for open, ping, close
  - poll requests
  - connector specific debug for networking messages

In SkySpark the Connector|Trace view provides a tool to debug a connector's
trace log.  You can also manage tracing with these Axon functions:

  - [connTrace()]: query the trace log
  - [connTraceIsEnabled()]: return if connector tracing is enabled
  - [connTraceEnable()]: enable tracing on a connector
  - [connTraceDisable()]: disable tracing on a connector
  - [connTraceClear()]: clear the trace log for a connector
  - [connTraceDisableAll()]: disable tracing on all connectors

Be aware that the trace log is stored in memory using a circular buffer.  For
connectors which trace their message payloads this can result in significant
RAM usage.  Tracing is always disabled by default on startup and must be
manually enabled on a per connector basis.  Use the `connTraceDisableAll()`
function after a debugging session.

# Poll Buckets
Most simple connectors support curVal synchronization via polling.  When
a connector's [pollMode](fan.hxconn::ConnPollMode) is defined as `buckets` then
the framework automatically allocates all points to *polling buckets*.
Polling buckets can be used to tune the grouping and frequency of polls.
Points are grouped into buckets via their unique [hx.conn::Conn.connTuningRef] tag.
Poll frequency is configured via the [pollTime] tag.  Note that two different
connTuning recs with the same pollTime are still modeled as two different buckets.

Example:

    id: @tuning-fast-1
    dis: "Fast Bucket 1"
    connTuning
    pollTime: 1sec

    id: @tuning-fast-2
    dis: "Fast Bucket 2"
    connTuning
    pollTime: 1sec

    id: @tuning-slow
    dis: "Slow Bucket"
    connTuning
    pollTime: 15sec

    dis: "Point F1-A", connTuningRef: @tuning-fast-1
    dis: "Point F1-A", connTuningRef: @tuning-fast-1
    dis: "Point F2-A", connTuningRef: @tuning-fast-2
    dis: "Point F2-B", connTuningRef: @tuning-fast-2
    dis: "Point S-A", connTuningRef: @tuning-slow
    dis: "Point S-B", connTuningRef: @tuning-slow

The configuration above will result in the following three poll buckets

    Fast Bucket 1 contains F1-A, F1-B
    Fast Bucket 2 contains F2-A, F2-B
    Slow Bucket contains S-A, S-B

Buckets are automatically staggered at startup so that groups are not
polled at the exact same interval.  In the example above, we have two buckets
configured with a 1sec pollTime.  The system will automatically stagger
the poll interval randomly within that 1sec window.

Under the covers a bucket is polled with the [onPollBucket](fan.hxconn::ConnDispatch.onPollBucket)
callback.  However, not all protocols support a batch read.  So it is possible
that bucket polls might still require individual point level read requests.