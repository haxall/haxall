//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Sep 2021  Matthew Giannini  Creation
//

using haystack
using math
using hxMath

@NoDoc class NDArray
{
//numpy.ndarray((3,2), numpy.dtype(">d"), numpy.array([1,2,3,4,5,6], dtype=">d"))
  static Dict encode(MatrixGrid g)
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
    for (i := 0; i < g.numRows; ++i)
    {
      for (j := 0; j < g.numCols; ++j)
      {
        buf.writeF8(g.float(i, j))
      }
    }
    nd["bytes"] = buf.flip
    return Etc.makeDict(nd)
  }

  static MatrixGrid decode(Dict spec)
  {
    rows := ((Number)spec["r"]).toInt
    cols := ((Number)spec["c"]).toInt
    buf  := ((Buf)spec["bytes"])
    // must use buf.in because buf is immutable
    in    := buf.in
    matrix := MMatrix(rows, cols)
    rows.times |i|
    {
      cols.times |j|
      {
        matrix.set(i, j, in.readF8)
      }
    }
    return Type.find("hxMath::MatrixGrid").method("makeMatrix").call(Etc.emptyDict, matrix)
  }
}