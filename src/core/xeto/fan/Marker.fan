//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Oct 2009  Brian Frank  Creation
//

**
** Marker is the singleton which indicates a marker tag with no value.
**
@Js
@Serializable { simple = true }
const final class Marker
{
  ** Singleton value
  const static Marker val := Marker()

  ** Always return `val`
  static new fromStr(Str s) { val }

  private new make() {}

  ** Return U+2713 "✓"
  override Str toStr() { "\u2713" }

  ** Return "✓"
  @NoDoc Str toLocale() { "\u2713" }

  ** If true return Marker.val else null
  static Marker? fromBool(Bool b) { b ? val : null }
}

