//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Aug 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto

**
** Parameterized spec arguments
**
@Js
const class MSpecArgs
{
  static const MSpecArgs nil := make

  virtual XetoSpec? of(Bool checked)
  {
    if (checked) throw haystack::UnknownNameErr("Missing 'of' meta")
    return null
  }

  virtual XetoSpec[]? ofs(Bool checked)
  {
    if (checked) throw haystack::UnknownNameErr("Missing 'ofs' meta")
    return null
  }
}

**************************************************************************
** MSpecArgsOf
**************************************************************************

**
** Arguments for 'of' meta
**
@Js
const class MSpecArgsOf : MSpecArgs
{
  new make(XetoSpec val) { this.val = val }
  const XetoSpec val
  override XetoSpec? of(Bool checked) { val }
}

**************************************************************************
** MSpecArgsOfs
**************************************************************************

**
** Arguments for 'ofs' meta
**
@Js
const class MSpecArgsOfs : MSpecArgs
{
  new make(XetoSpec[] val) { this.val = val }
  const XetoSpec[] val
  override XetoSpec[]? ofs(Bool checked) { val }
}