<!--
title:      HaystackExt
author:     Brian Frank
created:    21 Dec 2012
copyright:  Copyright (c) 2012, SkyFoundry LLC
license:    Licensed under the AFL v3.0
-->

# Overview
This library provides a client connector for the [Haystack HTTP API](ph.doc::HttpApi)
This connector can be used to communicate with other Haxall and SkySpark systems
which all implement the server side of the Haystack API protocol.  It is also
commonly used to communicate with Niagara via the [nHaystack](https://stackhub.org/package/nHaystack)
and [nhaystackAx](https://stackhub.org/package/nHaystackAx) modules.

The haystack connector provides full support for the following
connector features:
  - Learn tree via the [nav](op:nav) op
  - Current value subscription using [watches](hx.doc.haxall::Watches)
  - Writable point support using [pointWrite](op:pointWrite) op
  - History sync using the [hisRead](op:hisRead)  op

Note the [HaystackPoint.haystackCur], [HaystackPoint.haystackWrite], and [HaystackPoint.haystackHis] addresses
for this connector must all be *strings* (not refs).  This prevents them
from being confused as internal references.

# Current Points
Haystack proxy points are configured with [HaystackPoint.haystackCur] tag.  Subscription
uses [Haystack watches](hx.doc.haxall::Watches) to subscribe to the remote
points current value.  Watches use a poll for change design; you can tune
the poll frequency via the [HaystackConn.haystackPollFreq] connector tag.

# Writable Points
Haystack proxy points are configured to write to remote system points via
the [HaystackPoint.haystackWrite] tag.  The priority level to write to in the remote system
must be configured via the [HaystackPoint.haystackWriteLevel] tag.  The following point
would write its computed [ph::PhEntity.writeVal] to level 14 of "remote-point":

    point
    writable
    haystackConnRef: @conn
    haystackWrite: "remote-point"
    haystackWriteLevel: 14

# His Sync
Haystack proxy points are configured for history synchronization via the
[HaystackPoint.haystackHis] tag.  These points use the [hisRead](op:hisRead) op to read
history data from the remote system.
