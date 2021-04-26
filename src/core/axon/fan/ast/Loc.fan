//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Sep 2009  Brian Frank  Creation
//

**
** Source code location.
**
@Js
const class Loc
{
  ** Unknown location
  static const Loc unknown := Loc("unknown", 0)

  ** Generic eval location
  static const Loc eval := Loc("eval", 0)

  ** Constructor
  new make(Str file, Int line := 0)
  {
    this.file = file
    this.line = line
  }

  ** Location string
  override Str toStr()
  {
    if (line <= 0) return file
    else return "$file:$line"
  }

  ** Is this the unknown location
  Bool isUnknown() { this === unknown }

  ** File or func record name
  const Str file

  ** Line number (one based)
  const Int line
}