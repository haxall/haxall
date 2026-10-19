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

  ** Spec to render cells
  @NoDoc abstract Spec? cell()

  ** Spec to render cards
  @NoDoc abstract Spec? card()

  ** Spec to render blocks
  @NoDoc abstract Spec? block()

  ** Spec of input widget
  @NoDoc abstract Spec? input()

  ** Reference to ion::GroupItem
  @NoDoc abstract Ref? group()
}
