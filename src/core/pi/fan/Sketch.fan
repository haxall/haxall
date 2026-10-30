//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Oct 2026  Brian Frank  Creation
//

using dom
using xeto

**
** Sketch is an Axon template for HTML and SVG markup compiled
** against a namespace.  Use `PiEnv.sketch` to compile one.
**
@NoDoc @Js
const mixin Sketch
{
  ** Template source
  abstract Str src()

  ** Render this sketch to a DOM element with the given variables
  abstract SketchElem render(Str:Obj? vars)

  ** Return template source
  override Str toStr() { src }
}

**************************************************************************
** SketchElem
**************************************************************************

@Js @NoDoc
class SketchElem : Elem
{
  ** Constructor.  Pass 'Svg.ns' if its an SVG element
  new make(Str elemName, Uri? ns := null) : super(elemName, ns) {}

  ** Re-render this element with the given variables
  virtual Void rerender(Str:Obj? vars) {}
}

