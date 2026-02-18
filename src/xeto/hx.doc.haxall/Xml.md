<!--
title:      XML
author:     Brian Frank
created:    16 Apr 2011
copyright:  Copyright (c) 2011, SkyFoundry LLC
license:    Licensed under the Academic Free License version 3.0
-->

# Overview
XML or Extensible Markup Language is a common format used by
enterprises for data exchange.  Haxall supports a standardized
translation of [fan.haystack::Grid] into XML.  Note this format is **not**
standardized by Project Haystack, but rather is specific to Haxall.

# Usage
Fantom APIs:
  - [fan.xml::XParser] to decode into DOM
  - [fan.xml::XDoc] in-memory DOM model and writing
  - [fan.sys::OutStream] has many methods for XML escape sequences

Axon APIs:
  - [ioWriteXml()] to encode Grids

REST APIs:
  - [content negotiation](ph.doc::HttpApi#content-negotiation) for "text/xml" MIME type

# Grid Format
SkySpark defines a standard mapping of [fan.haystack::Grid] into XML which
is used by the REST API and [ioWriteXml()] function.  The XML representation
maintains full fidelity with the Haystack data model - all meta-data and
type information is maintained.  However the downside is that XML is much
more verbose than Zinc.

The Grid to XML mapping is as follows:

 - Top level `<grid ver="3.0">` element which contains:
   - An optional `<meta>` element with grid meta
   - One `<cols>` element with column definitions
   - Zero or more `<row>` elements with row definitions
 - A column definition is `<{name}>` with an optional `dis` attribute
   and optional `<meta>` child element (dis meta is always skipped)
 - Rows are encoded in `<row>` elements which contain values elements
 - Meta data and row values are encoded into `<{name}>` elements
 - Value cells always define a `kind` attribute with the kind name
   or "null" if the value is null
 - If the value is a scalar, then the `val` attribute maps to
   the Fantom 'toStr' representation of the value.  If the value is
   null, Marker, or Remove then the 'val' tag is omitted
 - Ref values may include an optional `dis` attribute
 - Values which are nested collections are encoded to a tree
   of children elements as illustrated in the examples below

Example:

    // Zinc
    ver:"3.0" projName:"test"
    dis dis: "Equip Name" primaryCol:M,equip,siteRef,installed
    "RTU-1",M,@153c600e-699a1886 "HQ",2005-06-01
    "RTU-2",M,@153c600e-699a1886 "HQ",1999-07-12

    // XML
    <grid ver='3.0'>
    <meta>
      <projName kind='Str' val='test'/>
    </meta>
    <cols>
      <dis dis='Equip Name'>
      <meta>
        <primaryCol kind='Marker'/>
      </meta>
      </dis>
      <equip/>
      <siteRef/>
      <installed/>
    </cols>
    <row>
      <dis kind='Str' val='RTU-1'/>
      <equip kind='Marker'/>
      <siteRef kind='Ref' dis='HQ' val='153c600e-699a1886'/>
      <installed kind='Date' val='2005-06-01'/>
    </row>
    <row>
      <dis kind='Str' val='RTU-2'/>
      <equip kind='Marker'/>
      <siteRef kind='Ref' dis='HQ' val='153c600e-699a1886'/>
      <installed kind='Date' val='1999-07-12'/>
    </row>
    </grid>

Nested list values:

    // Zinc
    ver:"3.0"
    list
    [1,2,3]

    // XML
    <grid ver='3.0'>
    <cols>
      <list/>
    </cols>
    <row>
      <list kind='List'>
        <item kind='Number' val='1'/>
        <item kind='Number' val='2'/>
        <item kind='Number' val='3'/>
      </list>
    </row>
    </grid>

Nested dict values:

    // Zinc
    ver:"3.0"
    dict
    {dis:"hello!", foo}

    // XML
    <grid ver='3.0'>
    <cols>
      <dict/>
    </cols>
    <row>
      <dict kind='Dict'>
        <dis kind='Str' val='hello!'/>
        <foo kind='Marker'/>
      </dict>
    </row>
    </grid>

Nested grid values:

    // Zinc
    ver:"3.0"
    grid
    <<
    ver:"3.0"
    dis
    "Grid"

    >>

    // XML
    <grid ver='3.0'>
    <cols>
      <grid/>
    </cols>
    <row>
      <grid kind='Grid'>
        <cols>
          <dis/>
        </cols>
        <row>
          <dis kind='Str' val='Grid'/>
        </row>
      </grid>
    </row>
    </grid>

You can also access SkySpark data via [oBIX](hx.obix::doc) which
is an alternate XML format.

