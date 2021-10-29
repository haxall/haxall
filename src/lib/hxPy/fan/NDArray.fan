//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Sep 2021  Matthew Giannini  Creation
//

using haystack
using math

@NoDoc class NDArray
{
//numpy.ndarray((3,2), numpy.dtype(">d"), numpy.array([1,2,3,4,5,6], dtype=">d"))
  static Dict encode(Grid g)
  {
    rows := g.size
    cols := g.cols.size
    nd := Str:Obj?[
      "ndarray": Marker.val,
      "r": Number.makeInt(rows),
      "c": Number.makeInt(cols),
    ]

    Float? f := null
    buf := Buf(rows * cols * 8)
    g.each |row, i|
    {
      row.each |val, name|
      {
        if (val is Number)    f = ((Number)val).toFloat
        else if (val is Bool) f = ((Bool)val) ? 1f : 0f
        else throw Err("Cannot encode $val [type=${val?.typeof}]. (row=$i, col=$name)")
        buf.writeF8(f)
      }
    }
    nd["bytes"] = buf.flip
    return Etc.makeDict(nd)
  }

  static Grid decode(Dict spec)
  {
    rows := ((Number)spec["r"]).toInt
    cols := ((Number)spec["c"]).toInt
    buf  := ((Buf)spec["bytes"])
    matrix := MMatrix(rows, cols)
    rows.times |i|
    {
      cols.times |j|
      {
        matrix.set(i, j, buf.readF8)
      }
    }
    return Type.find("hxMath::MatrixGrid").method("makeMatrix").call(Etc.emptyDict, matrix)
  }
}