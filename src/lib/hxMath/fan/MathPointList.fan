//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Feb 2012   Brian Frank   Creation
//

using haystack
using util

**
** MathPointList stores a list of x, y points and provides
** convenience methods.
**
internal class MathPointList
{
  new make(Grid grid, Dict? opts)
  {
    // get our x and y column
    if (grid.cols.size < 2) throw Err("Grid does not have 2 columns")
    xcol := grid.cols[0]
    ycol := grid.cols[1]

    // check options
    if (opts == null) opts = Etc.emptyDict
    if (opts.has("x")) xcol = grid.col(opts->x)
    if (opts.has("y")) ycol = grid.col(opts->y)

    // build up result
    acc := MathPoint[,]
    acc.capacity = grid.size
    xmean := 0f
    ymean := 0f
    grid.each |row|
    {
      xn := row.val(xcol) as Number
      yn := row.val(ycol) as Number
      if (xn == null || yn == null) return
      if (xn.isSpecial || yn.isSpecial) return
      x := xn.toFloat
      y := yn.toFloat
      acc.add(MathPoint(x, y))
      xmean += x
      ymean += y
    }

    // set fields
    if (acc.size == 0) throw Err("Grid has no x, y samples")
    this.points = acc
    this.n      = acc.size.toFloat
    this.xmean  = xmean/n
    this.ymean  = ymean/n
  }

  ** mean of x values
  const Float xmean

  ** mean of y values
  const Float ymean

  ** size as float
  const Float n

  Float x(Int index) { points[index].x }

  Float y(Int index) { points[index].y }

  @Operator MathPoint get(Int index) { points[index] }

  Void each(|MathPoint| f) { points.each(f) }

  private MathPoint[] points := [,]
}

internal const class MathPoint
{
  new make(Float x, Float y) { this.x = x; this.y = y }
  const Float x
  const Float y
  override Str toStr() { "$x, $y" }
}

