//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** Pi is the merged presentation info for a spec from all the `pi::Pi`
** instances bound to it.  Construct via `PiEnv.pi`.
**
@Js
const mixin Pi
{
  ** Merged tags
  abstract Dict meta()

  ** Icon to use for visualization
  abstract Icon? icon()

  ** Default color for visualization
  abstract ColorName? color()

  ** Display text
  abstract Text? text()

  ** Plural display text
  abstract Text? plural()

  ** Abbreviation for a chip or narrow column
  abstract Text? abbr()

  ** Customer specific display name standard for point specs
  abstract Str? pointDis()

  ** Tailwind CSS class list
  @NoDoc abstract Str? tw()

  ** Widget which draws a value of this type as a cell: one compact
  ** line such as a list row, tree node, tab or table cell.  It must
  ** be a subtype of `ion::ItemRenderer`.
  @NoDoc abstract Spec? cell()

  ** Spec of input widget; temp shim until inputs switch to sketches
  @NoDoc abstract Spec? inputType()
}

