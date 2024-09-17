//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//    6 Sep 2024  Brian Frank  Creation
//

using concurrent

**
** CompLayout models layout of a component on a logical grid coordinate system
**
@Js
const final class CompLayout
{
  ** Parse from string as "x,y,w"
  static new fromStr(Str s, Bool checked := true)
  {
    toks := s.split(',')
    if (toks.size >= 3)
    {
      x := toks[0].toInt(10, false)
      y := toks[1].toInt(10, false)
      w := toks[2].toInt(10, false)
      if (x != null && y != null && w != null) return make(x, y, w)
    }
    if (checked) throw ParseErr("Invalid CompLayout: $s")
    return null
  }

  ** Coerce CompLayout or Str to CompLayout
  @NoDoc static CompLayout coerce(Obj v)
  {
if (v is Dict)
{
  return make( v->x->toInt , v->y->toInt , v->w->toInt )
}
    return v as CompLayout ?: fromStr(v)
  }

  ** Constructor
  new make(Int x, Int y, Int w := 8)
  {
    this.xRef = x
    this.yRef = y
    this.wRef = w
  }

  ** Logical x coordinate
  Int x() { xRef }

  ** Logical y coordinate
  Int y() { yRef }

  ** Width in logical coordinate system
  Int w() { wRef }

  ** String representation as "x,y,w"
  override Str toStr() { "$x,$y,$w" }

  ** Return hash of x, y, and h
  override Int hash()
  {
    x.hash.xor(y.hash.shiftl(8)).xor(w.hash.shiftl(16))
  }

  ** Return if obj is same CompLayout value.
  override Bool equals(Obj? obj)
  {
    that := obj as CompLayout
    if (that == null) return false
    return this.x == that.x && this.y == that.y && this.w == that.w
  }

  private const Int xRef
  private const Int yRef
  private const Int wRef

}

