//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Oct 2026  Brian Frank  Creation
//

**
** Sketch is an Axon template for HTML and SVG markup
**
@NoDoc @Js
const mixin Sketch
{
  ** Create from template source
  static new fromStr(Str src) { MSketch(src) }

  ** Template source
  abstract Str src()

  ** Return template source
  override Str toStr() { src }
}

**************************************************************************
** MSketch
**************************************************************************

@Js
internal const class MSketch : Sketch
{
  static new fromStr(Str src) { make(src) }

  private new make(Str src) { this.src = src }

  override const Str src

  override Int hash() { src.hash }

  override Bool equals(Obj? that)
  {
    x := that as MSketch
    return x != null && src == x.src
  }
}

