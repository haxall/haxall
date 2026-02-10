<!--
title:      ObixExt
author:     Brian Frank
created:    17 May 2010
copyright:  Copyright (c) 2010, SkyFoundry LLC,
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
The [Obix](https://en.wikipedia.org/wiki/OBIX) protocol is a REST protocol
which uses an XML encoding.  The Obix connector implements both the client and
server side of the protocol.  The following features are supported:

**Obix Server**
  - reads of any record
  - history queries (any record tagged as [ph::PhEntity.his] maps to `obix:History`)
  - writable points are supported (if annotated correctly)
  - batch operations are supported
  - watches on records are supported
  - alarming is **not** supported

**Obix Client**
  - Obix connectors
  - proxy real-time points and watches supported
  - proxy writable points supported
  - proxy histories and synchronization supported
  - reads, writes, invokes all supported
  - alarming is **not** supported

# Server URIs
The following table summarizes the URIs of the Obix server API:

    Uri                              Object
    ------------------------         -------------
    {base}/obix/                     lobby
    {base}/obix/about/               about
    {base}/obix/batch/               batch op
    {base}/obix/watchService/        watch service
    {base}/obix/watch/{id}/          watch operations
    {base}/obix/query/{filter}       query recs using filter
    {base}/obix/rec/{id|name}/       record
    {base}/obix/rec/{id|name}/{tag}  tag
    {base}/obix/icon/{id}/{uri}      icon tunnelling

On Haxall nodes `{base}` will be `/api` and on SkySpark it will
be `/api/{proj}/ext`.

# Server Rec to Obix Mapping
The general rules are applied to map Folio records to Obix objects:
  - marker tags are mapped to the `is` contract as `tag:{name}`
  - tag name/value pairs are mapped as child objects of the appropriate scalar type
  - the `dis` tag is mapped to the `displayName` facet

Example:

    // folio
    {id:1331259c-95d44d6a, dis:"Bob", age:37, bday:1973-07-11,
     person, married, spouse:1331364b-eee35493}

    // obix
    <obj is="tag:person tag:married"
         displayName="Bob"
         href="/api/proj/ext/obix/rec/1331259c-95d44d6a/">
     <dis  name="dis"    href="dis"  val="Bob"/>
     <int  name="age"    href="age"  val="37"/>
     <date name="bday"   href="bday" val="1973-07-11"/>
     <ref  name="spouse" href="/api/proj/ext/obix/1331364b-eee35493/"/>
    </obj>

The following tags map to Obix contracts:
  - [ph::PhEntity.point] maps to `obix:Point`
  - [WritablePoint.obixWritable] maps to `obix:WritablePoint`
  - [ph::PhEntity.his] maps to `obix:History`
  - [ph::PhEntity.curVal] maps to point object `val` attribute
  - [ph::PhEntity.curStatus] maps to a point object `status` attribute

For example given this point record:

    id: 1746a5e5-a5d285cb
    point
    his
    dis: <Site-A RTU-2 Zone-Temp>
    siteRef: <Site-A>
    equipRef: <Site-A RTU-2>
    zone
    air
    temp
    sensor
    curVal: 72°F
    tz: New_York
    kind: Number

Maps to this Obix representation

    <real href="/api/proj/ext/obix/rec/1746a5e5-a5d285cb/"
         is="obix:Point obix:History tag:air tag:his tag:point tag:sensor tag:temp tag:zone"
         displayName="Site-A RTU-2 Zone-Temp"
         val="72" status="ok">
      <str name="tz" val="America/New_York"/>
      <op name="query" href="query" in="obix:HistoryFilter" out="obix:HistoryQueryOut"/>
      <str name="dis" href="dis" val="Site-A RTU-2 ZoneTemp"/>
      <ref name="equipRef" href="/api/proj/ext/obix/rec/1746a5e5-920b2573/" display="Site-A RTU-2"/>
      <strname="kind" href="kind" val="Number"/>
      <ref name="siteRef" href="/api/proj/ext/obix/rec/1746a5e5-7f296626/" display="Site-A"/>
    </real>

# Server Watches
The Obix server allows watches at the record level.  Watch URIs must
be formatted exactly as follows:

    {base}/obix/rec/{id}/

Any attempt to use a URI which doesn't match that format exactly or
is missing a trailing slash will result in a `BadUriErr` for the
subscription.  Obix server watches map directly to a [fan.hx::Watch].

On the initial poll, reference tags of type Ref will have their
`display` attribute available for the record reference.  But all polls
will omit the `display` attribute for performance.

# Obix Connectors
Client functionality is based on *Obix Connectors* which are created
using the [ObixConn.obixConn] tag.  Connectors are used to configure client
settings to communicate with a remote Obix server using these tags:

  - [hx.conn::Conn.conn]: required marker tag
  - [ObixConn.obixConn]: required marker tag
  - [ObixConn.obixLobby]: the absolute URI of the server's lobby (should end
    in a trailing slash)
  - [hx::User.username]: user name for authentication
  - [ObixConn.password]: must have password stored in [password db](hx.doc.haxall::Folio#passwords)
    for connector's record id

Obix connectors are built with the [connector framework](hx.doc.haxall::Conns)
and follow all the standard conventions.

Obix connectors will use [Haystack authentication](ph.doc::Auth) to connect
to the remote system.  You can force HTTP basic authentication by adding the
marker tag `obixBasicAuth` to your connector record.

After the first read operation with the connector (see [Funcs.obixPing])
the following tags are available on the connector:
  - vendorName: from about object
  - productName: from about object
  - productVersion: from about object
  - tz: timezone name of remote obix server

Some older versions of Obix may not be able to derive the [ph::PhEntity.tz]
tag from the ping, in which case you should manually configure
the tag to ensure that its available for history functions.

# Obix Connector Points
Obix proxy points are configured under a given connector using
the following tags:
  - [ObixPoint.obixConnRef]: references the Obix connector
  - [ObixPoint.obixCur]: URI to use for current value watches
  - [ObixPoint.obixWrite]: URI to for writable points
  - [ObixPoint.obixHis]: URI to use for `obix:History` for history synchronization

## Obix Cur
When an point with the [ObixPoint.obixCur] tag is put into watch, it subscribes to
a watch on the Obix server.  This subscription is used to maintain the current
point value via the [ph::PhEntity.curVal].  Watches are polled with a default frequency
of 1sec; you can tune this frequency with the [ObixConn.obixPollFreq] tag.

Also see [hx.point::doc#point-cur].

## Obix Writes
The [ObixPoint.obixWrite] URI is used to configure the `writePoint` operation of an
`obix:WritablePoint`.  Note the URI must reference the operation inside
the point object.  Changes to the local writable point are written to
the remote oBIX point.

Also see [hx.point::doc#point-writes].

## Obix His
A proxy point with the [ObixPoint.obixHis] tag is used to pull historical data
from an Obix connector into the local historian.  The Axon function
[hx.conn::Funcs.connSyncHis] is used pull the latest history data over the Obix connector
into the local historian.  You can use these functions to write
your own customized synchronization scripts.  The general convention
is to schedule history sync via [tasks](hx.task::doc).

Also see [hx.point::doc#point-his].

