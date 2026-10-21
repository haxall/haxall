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

  ** HTML template to render widget type
  @NoDoc abstract Sketch? widget()

  ** HTML template to render spec values in a CardView
  @NoDoc abstract Sketch? card()

  ** HTML template to render spec values as item cells in lists, trees, tables
  @NoDoc abstract Sketch? cell()

  ** HTML template to render spec values in forms
  @NoDoc abstract Sketch? input()

  ** SVG template to render spec as a block in a wiresheet view
  @NoDoc abstract Sketch? block()

  ** Tailwind CSS class list
  @NoDoc abstract Str? tw()

  ** Spec of input widget; temp shim until inputs switch to sketches
  @NoDoc abstract Spec? inputType()
}
