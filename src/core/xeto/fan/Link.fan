//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Nov 2023  Brian Frank  Thanksgiving
//   17 May 2024  Brian Frank  Sandbridge
//

using concurrent

**
** Link models a dataflow relationship between two Comp slots
**
@Js
const mixin Link : Dict
{
  ** Source component identifier
  abstract Ref fromRef()

  ** Soruce component slot name
  abstract Str fromSlot()
}

**************************************************************************
** Links
**************************************************************************

**
** Links models the incoming links of a component.  It is a dict
** keyed by the toSlot name.
**
@Js
const mixin Links : Dict
{
  ** Return if given toSlot has one or more links
  abstract Bool isLinked(Str toSlot)

  ** Iterate all the links as flat list
  abstract Void eachLink(|Str toSlot, Link| f)

  ** List all the links with the given toSlot name
  abstract Link[] listOn(Str toSlot)

  ** Add given link (if not duplicate) and return new instance of Links
  abstract This add(Str toSlot, Link link)

  ** Remove given link (if found) and return new instance of Links
  abstract This remove(Str toSlot, Link link)
}

