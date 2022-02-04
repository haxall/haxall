//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jan 2010  Brian Frank  Creation
//   05 Feb 2012  Brian Frank  Refactor for new DateSpan design
//   04 Feb 2022  Brian Frank  Move from axon into haystack
//

**
** ObjRange models ".." range literal.
**
@Js @NoDoc
const final class ObjRange
{
  new make(Obj? start, Obj? end) { this.start = start; this.end = end }

  ** Starting value
  const Obj? start

  ** Ending value
  const Obj? end

  ** Hash code based on start, end
  override Int hash() { toStr.hash }

  ** Equality code based on start, end
  override Bool equals(Obj? that)
  {
    x := that as ObjRange
    if (x == null) return false
    return start == x.start && end == x.end
  }

  ** String format is "start..end"
  override Str toStr() { "${start}..${end}" }

  ** Does this range inclusively contain the value
  Bool contains(Obj? val) { start <= val && val <= end }

  ** Construct from inclusive sys::Range
  static ObjRange fromIntRange(Range r)
  {
    if (!r.inclusive) throw ArgErr("Not inclusive: $r")
    return make(Number(r.start), Number(r.end))
  }

  ** Return as an inclusive sys::Range
  Range toIntRange()
  {
    try
    {
      s := start; si := s is Number ? ((Number)s).toInt : (Int)s
      e := end;   ei := e is Number ? ((Number)e).toInt : (Int)e
      return Range.makeInclusive(si, ei)
    }
    catch (CastErr e) throw CastErr("Cannot convert to int range: $this")
  }
}