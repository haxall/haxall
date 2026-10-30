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

  ** Render this sketch to a DOM element with the given scope variables
  abstract SketchElem renderElem(SketchScope scope)

  ** Render this sketch to a markup string with the given scope variables
  abstract Str renderStr(SketchScope scope)

  ** Return template source
  override Str toStr() { src }
}

**************************************************************************
** SketchScope
**************************************************************************

@Js @NoDoc
mixin SketchScope
{
  ** Get a variable by name or null if not defined
  abstract Obj? get(Str name)
}

**************************************************************************
** SketchElem
**************************************************************************

@Js @NoDoc
abstract class SketchElem : Elem
{
  ** Constructor.  Pass 'Svg.ns' if its an SVG element
  new make(Str elemName, Uri? ns := null) : super(elemName, ns) {}

  ** Re-render this element with the given variables
  abstract Void rerender(SketchScope scope)
}

