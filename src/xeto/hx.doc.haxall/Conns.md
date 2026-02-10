<!--
title:      Connectors
author:     Brian Frank
created:    4 Jul 2012
copyright:  Copyright (c) 2012, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
The connector framework provides a standardized model for integrating
to external systems.  It is based upon the following key features:
  - **Connector**: a record which represents a connection to an external
    system or device
  - **Connector Point**: proxy point bound to a connector used to
    synchronize current value, writable value, or history
  - **Tuning**: a broad set of configuration options to fine tune
    connector behavior and performance
  - **Learning**: many connectors provide a mechanism to "walk" the
    external system for point-and-click UI tools
  - **Diagnostics**: the framework includes detailed debugging and
    network tracing tools
  - **Axon API**: a suite of Axon functions to access protocol specific functionality
  - **Fantom API**: a suite of Fantom APIs make it easy to create your
    own custom connectors

# Included Connectors
Haxall provides a rich library of ready to use connectors:
  - [Haystack](hx.haystack::doc): provides client connectivity via the
    Haystack HTTP API (used for Niagara)
  - [MQTT](hx.mqtt::doc): connects to a broker to publish and subscribe to topics
  - [SQL](hx.sql::doc): connect to relational databases using JDBC
  - [Modbus](hx.modbus::doc): client support for TCP and RTU modbus protocols
  - [oBIX](hx.obix::doc): client and server support for oBIX XML protocol
  - [Sedona](hx.sedona::doc): client support for the Sedona Sox protocol
  - [Ecobee](hx.ecobee::doc): connect to Ecobee thermostats
  - [Nest](hx.nest::doc): connect to Google smart device management including Nest thermostats

SkySpark includes the following additional connectors:
  - [BACnet](hx.bacnet::doc): client support for BACnet IP
  - [OPC](hx.opc::doc): client support for OPC UA
  - [EnergyStar](hx.energystar::doc): integration with Energy Star Portfolio Manager
  - [SNMP](hx.snmp::doc): client support for SNMP typically used with IT equipment

Many third party connectors are also available on [StackHub](https://stackhub.org).
Or you can build your own [custom connector](CustomConns) with the connector
framework APIs.

# Naming Conventions
The connector framework relies heavily on naming conventions to promote consistency.
Everything is based on the library name. Let's look at the `haystack` connector
as an example:

  - [hx.haystack::HaystackConn.haystackConn]: marker tag for the connector rec
  - [hx.haystack::HaystackPoint.haystackPoint]: marker tag for the associated points
  - [hx.haystack::HaystackPoint.haystackConnRef]: reference on each point to its parent connector
  - [hx.haystack::HaystackPoint.haystackCur]: address for curVal subscription
  - [hx.haystack::HaystackPoint.haystackWrite]: address for writable points
  - [hx.haystack::HaystackPoint.haystackHis]: address for history data synchronization

This same pattern is enforced by the connector framework across all connector
types.  If you know the library name, then you can infer all the other names.

# Connectors
Each connector instance is a record in the [Folio] database that models a logical
connection to a remote system.  A connector might model an external device,
server, or database.  Each connector has a unique address and communication
protocol to integrate with the external entity.

The following tags are typically used to configure a connector:
  - `fooConn`: required marker tag for specific connector type
  - `conn`: required marker tag
  - `uri`: most connectors use this tag for the address of remote system
  - `username`: when authentication is required to remote system
  - `password`: when authentication is required, then password should be stored
    in [password db](Folio#passwords)` by connector's record id
  - `disabled`: marker tag which disables the connector

The following transient status tags are managed by the framework itself:
  - [hx.conn::Conn.connStatus]: ok, down, fault or disabled
  - [hx.conn::Conn.connState]: close, opening, open, or closing
  - [hx.conn::Conn.connErr]: error message if connStatus indicates error condition
  - additional debugging details are available via the [details](ConnTuning#details)

In addition to the tags above, each connector defines its own tags for
meta data about the remote system/device.  This data is queried from the
remote system during [ping](connPing()) and typically includes:
  - make and model of remote device or software
  - hardware/software version of remote system

# Connector State
Every connector maintains an open/close state available via the [hx.conn::Conn.connState] tag:
  - `closed`: connector is closed
  - `closing`: connector is currently inside its [onClose](fan.hxconn::ConnDispatch.onClose) callback
  - `open`: connector is open
  - `opening`: connector is currently inside its [onOpen](fan.hxconn::ConnDispatch.onOpen) callback

The framework manages the state, however the semantics of open will vary based
on the connector type.  For session based HTTP connectors open means that a
session has been obtained to reuse between calls.  For TCP connectors it means
that a socket has been open to the remote system.  For UDP protocols it might
mean only that a ping request has been successful.

Separately every connector maintains a status via the [hx.conn::Conn.connStatus] tag:
  - `ok`: connectivity is normal
  - `fault`: configuration problem
  - `down`: communication or network problem
  - `disabled`: manual disable using the [hx::User.disabled] tag
  - `unknown`: status not computed yet (boot state)

The status is managed by the framework; typically it is transitioned after
the [onOpen](fan.hxconn::ConnDispatch.onOpen)  callback either succeeds or fails.
Note that is common for the state to be both `ok` and `closed` - a connector is
not kept open unless an application has a current need for it to be open.

# Connector Points
Most connectors support synchronization of [point](ph.doc::Points) data:
  - [cur](#point-cur): subscription/polling of current, real-time value
  - [writes](#point-writes): writing to an output
  - [history sync](#point-history-sync): synchronization of time-series history data

Connector points are modeled as follows:
  - Must be adhere to standard [point ontology](ph.doc::Points)
  - `fooPoint`: annotates the point as a specific connector type
  - `fooConnRef`: associates the point with a specific connector
  - `fooCur`: remote system address to synchronize real-time current value
  - `fooWrite`: remote system address used to write to an output
  - `fooHis`: remote system address to synchronize historical time-series data

Not every connector supports all three features, in which case only the
applicable tags are used.  Each of these point features is described in more
detail below.

# Point Cur
Points which support [current value](ph.doc::Points#cur-points) are modeled
with the [ph::PhEntity.cur] tag.  Connectors can be used to automatically synchronize
a point's current value using the [ph::PhEntity.curVal] tag.  Current value synchronize
occurs one of two ways:
  1. Manual synchronization via the [connSyncCur()] function
  2. Automatically when the point is put into a [watch](hx.doc.haxall::Watches)

The mechanism for current value synchronization is specific to each connector
type and protocol.  However most connectors use one of the following strategies:
  - periodical polling of points in a watch - tunable by
    the [pollTime](ConnTuning#polltime) configuration option
  - change-of-value (COV) subscription for protocols which support it

Connector points, which are using current value subscription will maintain
their status via the [ph::PhEntity.curStatus] tag:
  - `ok`: all is okay
  - `stale`: the point's curVal is not fresh data
  - `fault`: a configuration or hardware problem - see [ph::PhEntity.curErr]
  - `down`: a communication or network problem - see [ph::PhEntity.curErr]
  - `disabled`: manual disable of the point or connector
  - `unknown`: we don't know anything (boot state)
  - `remoteFault`: point in remote system is fault
  - `remoteDown`: point in remote system is down
  - `remoteDisabled`: point in remote system is disabled
  - `remoteUnknown`: point in remote system is unknown

If the parent connector is in an error/disable state, then all child points
automically inherit the connector status.

The framework will automatically transition the status from "ok" to "stale" after 5min.
This time can be tuned via the [staleTime](ConnTuning#staletime) option.

# Point Writes
Haystack models [writable points](ph.doc::Points#writable-points) with the [ph::PhEntity.writable]
marker tag.  Writable points maintain an internal 16 level priority array
by the [point library](hx.point::doc#point-writes).  The effective value of the priority
array is available via the [ph::PhEntity.writeVal] and [ph::PhEntity.writeLevel] transient tags.  The
effective level may be written to a remote system by connector.  By default
writes are issued whenever the local array's effective value is modified.
However there are many tuning options to control write timing:
  - [writeMinTime](ConnTuning#writemintime): throttles writes
  - [writeMaxTime](ConnTuning#writemaxtime): periodically re-issues writes
  - [writeOnStart](ConnTuning#writeonstart): force write on startup
  - [writeOnOpen](ConnTuning#writeonopen): force write when connector transitions to open

Connector points configured to write will maintain their status via
the [ph::PhEntity.writeStatus] tag:
  - `ok`: last write was successful
  - `down`: connectivity/networking problem - see [ph::PhEntity.writeErr]
  - `fault`: configuration or hardware error  - see [ph::PhEntity.writeErr]
  - `disabled`: manual disable of the point or connector
  - `unknown`: we don't know anything (boot state)

If the parent connector is in an error/disable state, then all child points
automically inherit the connector status.

# Point History Sync
Some connectors support history data synchronization when the underlying
protocol provides the respective feature.  History syncs must be scheduled with
the [task library](hx.task::doc) and the [connSyncHis()] function.  After
the initial history sync, then this function is scheduled using a `null` span
to sync history items after the last sync.

Here is an example task that synchronizes all haystack history points every 1hr:

    dis:"Sync Haystack Histories"
    obsSchedule
    obsScheduleFreq:1h
    task
    taskExpr: "readAll(haystackHis).connSyncHis(null)"

Connector points configured to sync history maintain their status via
the [ph::PhEntity.hisStatus] tag:
  - `ok`: last sync attempt was successful
  - `fault`: a configuration problem - see [ph::PhEntity.hisErr]
  - `down`: a communication or network problem - see [ph::PhEntity.hisErr]
  - `disabled`: manual disable of the point or parent connector
  - `unknown`: we don't know anything (boot state)
  - `pending`: sync has been scheduled and is waiting to running
  - `syncing`: not used by connector framework

If the parent connector is in an error/disable state, then all child points
automically inherit the connector status.

For connectors which do not provide history synchronization, you can setup
current value subscription and use local [history collection](hx.point::doc#his-collect)

# Point Conversions
The following tags are used to configure conversions between the normalized
data stored in Folio and the connector's remote device:
  - [hx.conn::ConnPoint.curConvert]: converts from raw read value to curVal
  - [hx.conn::ConnPoint.curCalibration]: adjusts read value before updating curVal
  - [hx.conn::ConnPoint.writeConvert]: converts local writeVal to raw value to write to remote system
  - [hx.conn::ConnPoint.hisConvert]: converts history items read from remote system before storing locally

The conversion is specified as a string using the [point convert syntax](hx.point::doc#point-conversion).

For example, if a connector provides temperature data in Celsius which we
wish to convert to Fahrenheit, then we can add this tag to our point:

     curConvert: "°C => °F"

If the sensor needs calibration, we might further decide to adjust plus or
minus a few degrees.  If for example we wanted to add 2°F to the value being
read from the sensor then:

     curConvert: "°C => °F"
     curCalibration: 2°F

If we were also writing a value for the same point, then we would need to
reverse the conversion for the write direction:

     curConvert: "°C => °F"
     curCalibration: 2°F
     writeConvert: "°F => °C"

Use the [details](ConnTuning#details) to debug the raw and converted values.

# Multiple Connectors
Standard practice is to associate a given point to one connector.  However, it
is possible to assign a point to multiple connectors for different protocols.
For example, a point can have both a `bacnetConnRef` and a `sqlConnRef`.  When
you configure a point this way, the default behavior is to log a warning:

    Duplicate conn refs: bacnet + sql [@xyz]

If you truly wish to use multiple connectors, then you must apply
the `connDupPref` tag with the connector name that should take precedence.
This is the protocol that will be used by default for operations such as
auto-subscription of watches and history syncs:

    dis: "Dual Conn Point"
    point
    bacnetPoint
    sqlPoint
    bacnetConnRef: @bacnet-conn
    sqlConnRef: @sql-conn
    connDupPref: "bacnet"

You can explicitly determine which connector is used for the [connSyncCur()]
and [connSyncHis()] functions by using the [connPointsVia()] function.

Note: the system cannot update its lookup tables on the fly when adding/changing
the `connDupPref` tag.  You will need a restart for it to take effect.

