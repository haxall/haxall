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

  ** Formal params: the only names taken from the vars it is given
  abstract Str[] params()

  ** Tag of its one root element, which is fixed
  abstract Str rootTag()

  ** Create an instance: draw this sketch into the given element as
  ** its root, which must have the `rootTag`
  abstract SketchInstance renderInstance(Elem elem, Str:Obj? vars)

  ** Render this sketch to a markup string with the given vars
  abstract Str renderStr(Str:Obj? vars)

  ** Return template source
  override Str toStr() { src }
}

**************************************************************************
** SketchSrc
**************************************************************************

**
** SketchSrc wraps the source code of a `Sketch` template.  Use
** `PiEnv.sketch` to compile it against a namespace.
**
@NoDoc @Js
const class SketchSrc : SrcStr
{
  ** Wrap string - the string is *not* parsed for syntax correctness
  static new fromStr(Str src) { make(src) }

  ** Constructor
  private new make(Str src) { this.src = src }

  ** Source code
  override const Str src

  ** Hash is based on source code
  override Int hash() { src.hash }

  ** Equality is based on source code
  override Bool equals(Obj? that)
  {
    x := that as SketchSrc
    return x != null && src == x.src
  }
}

**************************************************************************
** SketchInstance
**************************************************************************

**
** SketchInstance is one instance of a `Sketch`: the element it was
** drawn into, the current vars, and what its drawing recorded.
** Use `Sketch.renderInstance` to create one.
**
@Js @NoDoc
abstract class SketchInstance
{
  ** Sketch this is an instance of
  abstract Sketch sketch()

  ** Root element this was drawn into
  abstract Elem elem()

  ** Current value of each param
  abstract Str:Obj? vars()

  ** Update to the given vars, writing only what changed
  abstract Void update(Str:Obj? vars)
}

