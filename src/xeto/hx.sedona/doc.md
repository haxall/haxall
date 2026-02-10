<!--
title:      SedonaExt
author:     Brian Frank
created:    3 Feb 2022
copyright:  Copyright (c) 2022, SkyFoundry LLC
license:    Licensed under the AFL v3.0
-->

# Overview
This library provides a connector for the Sedona Sox protocol.  Sox is
a binary UDP protocol for comminication to controllers which run the
[Sedona Framework](https://www.sedona-alliance.org/) control engine.

The sedona connector provides the following features:
  - Learn support to walk the remote device component tree
  - COV subscription to any component property
  - Writable support to any component property

# Connectors
Sedona client connectors are configured with the following tags:

 - [hx.conn::Conn.conn]: required marker tag
 - [SedonaConn.sedonaConn]: required marker tag
 - [SedonaConn.uri]: formatted as "sox://host:port" such as "sox://192.168.1.88:1876"
 - [hx::User.username]: user name for authentication
 - [SedonaConn.password]: must have password stored in password db for connector's record id

After the first ping the following meta data tags are available:
  - sedonaVersion
  - sedonaPlatform

# Points
Points use the following tags:
  - [SedonaPoint.sedonaPoint]: required marker tag
  - [SedonaPoint.sedonaConnRef]: associated connector
  - [SedonaPoint.sedonaCur]: address to subscribe for curVal
  - [Funcs.sedonaWrite]: address to write for a local writable point

The address strings are formatted as "compId.slot".  An example address
might be "4.out" where the compId is the component's integer identifier
and slot is the string name.

# Manifests
Sedona connectors require a manifest XML file for each kit used by the
remote devices.  Manifests are stored under in the var/etc directory
using this naming convention:

    {var}/etc/sedona/manifests/{kit}/{kit}-{checksum.xml}

For example the "math" kit manifest with a checksum of "c22b255c" would
be stored in the following file:

    {var}/etc/sedona/manifest/math/math-c22b255c.xml

If running SkySpark, then manifests may be managed under the Sedona Manifests
view under the Connectors app.
