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

  ** Soruce component slot name
  abstract Str toSlot()
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
  ** List all the links as flat list
  abstract Link[] list()

  ** List all the links with the given toSlot name
  abstract Link[] on(Str slot)
}

