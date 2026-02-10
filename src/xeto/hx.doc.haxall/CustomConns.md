<!--
title:      Custom Connectors
author:     Brian Frank
created:    4 Jul 2012
copyright:  Copyright (c) 2012, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
The connector framework is defined as a suite of Fantom APIs in the
[hxConn](fan.hxConn::index) pod.  The framework handles all the complicated
details for threading, timers, and state management - it boils your
implementation down to a set of callbacks.  This design allows you to quickly
create own custom connectors and enforces consistency across all connector
types.

Key classes in the API:
  - [fan.hxconn::ConnExt]: your HxLib subclass
  - [fan.hxconn::Conn]: models one connector as an actor
  - [fan.hxconn::ConnPoint]: models one point under a connector
  - [fan.hxconn::ConnDispatch]: base class for callback handling
  - [fan.hxconn::ConnTrace]: used to add tracing into your connector

# Steps
To create a custom connector requires the following steps:
  1. Stub out a new Fantom [pod](#fantom-pod)
  2. Create your tag [definitions](#defs)
  3. Create your [ConnExt](#connext) subclass
  4. Create your [ConnDispatch](#conndispatch) subclass to handle callbacks

Tip: Use the [hx stub tool](Exts#stub) to stub out the code needed for a custom connector:

    hx stub -type conn acmeFoo

There are several additional, optional steps depending on the features
you wish to support:

  1. Implement [learn](#learn) tree
  2. Implement point [curVal](#point-cur) support
  3. Implement point [writes](#point-writes)
  4. Implement point [history sync](#point-history-sync)
  5. Provide additional Axon [functions](#axon-funcs) for your connector

All tag and class names will be derived from your library name.  You cannot
deviate from the naming conventions - the framework expects your tags and
class names to follow the standard naming patterns.

# Fantom Pod
All connectors must be defined as a Fantom [pod](fan.doc.lang::Pods).  You will
typically have the following source level directory structure:

    hxFoo/
      build.fan
      lib/
        lib.trio
        conn.trio
        point.trio
      fan/
        FooLib.fan
        FooDispatch.fan
        FooFuncs.fan
      test/
        FooConnTest.fan

TODO: that conn still require you register a lib.trio for the defs:

    index = ["ph.lib": "foo"]

# Defs
All connectors are a subclass of [Ext](Exts) which implement a Haystack
extension in Fantom.  Your connector must formally define all its tags for
connector and point records.

The library definition should follow the standard liib defs:

    // lib.trio
    def: ^lib:foo
    depends: [^lib:ph, ^lib:axon, ^lib:hx, ^lib:conn]
    typeName:"hxFoo::FooLib"
    doc: "My custom foo connector"

Define your connector rec defs as follows:

    // conn.trio
    def: ^fooConn
    is: ^conn
    connFeatures: {learn, pollMode:"buckets"}
    doc: "My custom foo connector"
    ---
    defx: ^uri
    tagOn: ^fooConn
    ---
    defx: ^username
    tagOn: ^fooConn
    ---
    defx: ^password
    tagOn: ^fooConn

What tags you define on your connector will be dependent on what data
is required to connect to the endpoint.  Most connectors that require
authentication will by convention use the tags: uri, username, and
password (as shown above for example purposes).

The [hx.conn::Spec.connFeatures] tag declares the features you connector supports - it is
introspected by the framework when your connector boots.  The value must be
a nested Dict that uses the following tags:

  - `learn`: marker tag if your connector supports [learn](#learn)
  - `pollMode`: enum for [fan.hxconn::ConnPollMode] - see [below](#polling)

If your connector will support points, then you will also need definitions
for the point and associated addressing tags:

    // point.trio
    def: ^fooPoint
    is: ^connPoint
    doc: "Point which synchronizes data via a foo connector."
    ---
    def: ^fooConnRef
    is: ^ref
    of: ^fooConn
    tagOn: ^fooPoint
    doc: "Associate a point to its parent foo connector"
    ---
    def: ^fooCur
    is: ^str
    tagOn: ^fooPoint
    doc: "Current value address for foo connector points"
    ---
    def: ^fooWrite
    is: ^str
    tagOn: ^fooPoint
    doc: "Write address for foo connector points"
    ---
    def: ^fooHis
    is: ^str
    tagOn: ^fooPoint
    doc: "History sync address for foo connector points"

The address tags and their value type will be dependent on your
specific protocol.  Most connectors use `str` or `uri` for the
address type.

# ConnExt
All connectors must create a subclass of [fan.hxconn::ConnExt].
Here is an example:

    using hx
    using hxConn

    const class FooExt: ConnExt
    {
    }

In most cases, this will just be empty stub code.  But there are some features
which require overrides.  For example, if you want to add extra debugging into
details, then you will override the [onConnDetails](fan.hxconn::ConnExt.onConnDetails)
or [onPointDetails](fan.hxconn::ConnExt.onPointDetails) methods.

# ConnDispatch
All connectors must create a subclass of [fan.hxconn::ConnDispatch] to handle
callbacks.  Any mutable state your connector manages should be stored in
this class.  One instance of this class is instantiated per connector by
the [fan.hxconn::Conn] actor.

All implementations must handle the following callbacks:

  - [onOpen](fan.hxconn::ConnDispatch.onOpen)
  - [onPing](fan.hxconn::ConnDispatch.onPing)
  - [onClose](fan.hxconn::ConnDispatch.onClose)

Here is a simple stub example:

    class FooDispatch : ConnDispatch
    {
      new make(Obj arg) : super(arg)
      {
        // must call super with opaque arg
        // parent runtime and conn is available within your constructor
      }

      override Void onOpen()
      {
        // open your connector here
        // raise exception if open fails
      }

      override Void onClose()
      {
        // close and cleanup goes here
      }

      override Dict onPing()
      {
        // ping the device and return a dict with meta data for conn rec
      }
    }

# Learn
The learn feature is used to "walk" the external system's native data model
to discover which points are available.  To add learn to your connector:
 1. define the `learn` tag in your conn defs [hx.conn::Spec.connFeatures]
 2. override the [onLearn](fan.hxconn::ConnDispatch.onLearn) callback

The learn argument is an connector specific identifier used to keep of
track of position within the tree or graph of the remote system's data model.
The null argument indicates a call to learn the root of the tree.  Each call
to learn takes the argument and returns a grid of the items at that level of
the tree.  If an item may be navigated into as a "folder", then it should
define its own learn identifier in the `learn` column.

If a learn item supports mapping to a point, then your resulting grid should
include standard point data like `point`, `fooPoint`, `fooCur`, `fooWrite`,
`fooHis`, `kind`, `unit`, etc.

# Point Cur
Current value is synchronized manually via the [connSyncCur()] function which
results in the [onSyncCur](fan.hxconn::ConnDispatch.onSyncCur) callback.  This
callback works with a batch of points.  If your protocol supports batch reads,
then typically it most efficient to sync the entire batch.

Continuous synchronization of current value is managed when the point is put
into a [watch](hx.doc.haxall::Watches).  Watch state is managed by the callbacks
[onWatch](fan.hxconn::ConnDispatch.onWatch) and [onUnwatch](fan.hxconn::ConnDispatch.onUnwatch).
Both callbacks work with a batch of points. Typically there are two
watch strategies:
  - if the protocol supports change of value subscriptions, then map
    watch/unwatch callbacks to the subscribe/unsubscribe
  - if the protocol does not support subscriptions, then your
    connector should use the poll scheduler to periodically poll
    the points in watch. Point polling is described in more detail
    in the [polling](#polling) section.

There are many ways that your points will end up synchronizing their
current value:
  - one time `onSyncCur` read
  - initial subscription from `onWatch`
  - async message from subscription change-of-value events
  - periodic [polling](#polling)

In all cases if the current value is read successfully, then the connector
should call [updateCurOk](fan.hxconn::ConnPoint.updateCurOk) with the Haystack
representation of the current value.  If an error is detected such as
a bad address, then call [updateCurErr](fan.hxconn::ConnPoint.updateCurErr).
These methods manage the `curVal`, `curStatus`, and `curErr`
tags for you automatically.

As a general principle, if there is an exception reading a point then
call `updateCurErr` with the exception.  The following exceptions type
should be used for special cases:
  - [fan.haystack::FaultErr]: connector is communicating correctly, but
    there is a configuration error with the point
  - [fan.hxconn::RemoteStatusErr]: remote point can be read correctly, but
    the remote system status is not "ok".  For example if the remote
    point is "disabled", then use this exception to set the local point
    into "remoteDisabled"

# Point Writes
The standard behavior of writable points is defined by the [point library](hx.point::doc#point-writes)
which manages the 16-level priority array.  When it calculates a new effective
level should be written, the framework issues the [onWrite](fan.hxconn::ConnDispatch.onWrite)
callback.  Your callback should write the new value to the remote system, and
then call [updateWriteOk](fan.hxconn::ConnPoint.updateWriteOk) or [updatWriteErr](fan.hxconn::ConnPoint.updateWriteErr).

# Point History Sync
If the connector's protocol supports historical time-series synchronization,
then implement the [onSyncHis](fan.hxconn::ConnDispatch.onSyncHis) callback.  Use
this callback to read the history items for the given timestamp range.  Your
callback must then call [updateHisOk](fan.hxconn::ConnPoint.updateHisOk) with latest
data or else call [updateHisErr](fan.hxconn::ConnPoint.updateHisErr) if there is an
error.  The framework automatically handles writing to the historian and managing
your `hisStatus` and `hisErr` tags.

# Polling
Polling is the process by which the connector syncs the current value for a batch
of points that are in watch.  There are two different polling models provided
by the framework: 1) manual and 2) buckets.  To enable one of these polling
features add the `pollMode` tag in the [hx.conn::Spec.connFeatures] of your conn definition.

## Manual Polling
Manual polling is used when your connector wishes to handle all polling details
itself.  For example, it is used by the Haystack and oBIX connectors to implement the
"poll for changes" design pattern.  The framework invokes the [onPollManual](fan.hxconn::ConnDispatch.onPollManual)
callback based on a configured frequency.  To use manual polling your library
must define a tag named `fooPollFreq`:

    def: ^fooPollFreq
    is: ^duration
    tagOn: ^fooConn
    val: 5sec

The `val` tag determines the default frequency when not explicitly configured.

## Buckets Polling
Bucket polling is the standard, built-in strategy to achieve tunable, scalable
polling for a large number of points. Bucket polling is described in detail in
the [Tuning](ConnTuning#poll-buckets) chapter.  From an implementation
perspective, all that you must do is override the [onPollBuckets](fan.hxconn::ConnDispatch.onPollBucket)
callback.  If you don't override this method, then it will automatically
route to [onSyncCur](fan.hxconn::ConnDispatch.onSyncCur).

# Custom Messaging
Each Conn instance is a subclass of [fan.concurrent::Actor] which accepts
messages typed as [fan.hx::HxMsg].  Built-in messages are routed to your
ConnDispatch subclass via the various callbacks.  But you can also add custom
messages which will be dispatched to the [onReceive](fan.hxconn::ConnDispatch.onReceive)
callback.  This callback only receives messages which are not handled
by the framework.  So when using this feature, make sure to use names
which will never conflict with the built-in message types; a good technique
is to prefix all your message ids with your library name.  Exceptions
raised by `onReceive` are not logged, but instead raised to the calling
thread by the future.

# Axon Funcs
If you wish to provide Axon functions specific to your connector, then use
the standard pattern of a [FooFuncs](Namespace#fantom-funcs) class.  The typical pattern
is to lookup your ConnLib and then use that to resolve the Conn and ConnPoint
instances for dispatch.  Here is some example code:

    class FooFuncs
    {
      ** Example connector function
      @Axon { admin = true }
      static Future fooConnSomething(Obj conn)
      {
        cx := HxContext.curHx
        lib := (FooLib)cx.rt.lib("foo")
        c := lib.conn(Etc.toId(conn))
        return c.send(HxMsg("connSomething"))
      }

      ** Example point function
      @Axon { admin = true }
      static Future fooPointSomething(Obj pt)
      {
        cx := HxContext.curHx
        lib := (FooLib)cx.rt.lib("foo")
        p := lib.point(Etc.toId(pt))
        return p.conn.send(HxMsg("pointSometing", p))
      }
    }

