//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using haystack
using axon

**
** StreamTest
**
@Js
class StreamTest : AxonTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    // list stream
    verifyStream("[1, 2, 3, 4].stream.collect", Obj?[n(1), n(2), n(3), n(4)])

    // range stream
    verifyStream("(1..4).stream.collect", Obj?[n(1), n(2), n(3), n(4)])
    verifyStream("(-3..-1).stream.collect", Obj?[n(-3), n(-2), n(-1)])
    verifyStream("(5..3).stream.collect", Obj?[n(5), n(4), n(3)])
    verifyEq(((List)eval("(1..3).stream.collect")).isImmutable, true)

    // map
    verifyStream("[1, 2, 3, 4].stream.map(v=>v*2).collect", Obj?[n(2), n(4), n(6), n(8)])

    // flatMap
    verifyStream("[1, 2, 3, 4].stream.flatMap(v=>[v, -v]).collect", Obj?[n(1), n(-1), n(2), n(-2), n(3), n(-3), n(4), n(-4)])
    verifyStream("[1, 2, 3, 4].stream.flatMap(v=>[v, -v]).findAll(v=>v==2).collect", Obj?[n(2)])
    verifyStream("[1, 2, 3, 4].stream.flatMap(v=>[v, -v]).find(v=>v==2)", n(2))

    // findAll
    verifyStream("[1, 2, 3, 4].stream.findAll(v=>v.isEven).collect", Obj?[n(2), n(4)])
    verifyStream("[1, 2, 3, 4].stream.findAll(v=>v.isEven).map(v=>v*2).collect", Obj?[n(4), n(8)])

    // limit
    verifyStream("[1, 2, 3, 4].stream.limit(10).collect", Obj?[n(1), n(2), n(3), n(4)])
    verifyStream("[1, 2, 3, 4].stream.limit(4).collect", Obj?[n(1), n(2), n(3), n(4)])
    verifyStream("[1, 2, 3, 4].stream.limit(3).collect", Obj?[n(1), n(2), n(3)])
    verifyStream("[1, 2, 3, 4].stream.limit(2).collect", Obj?[n(1), n(2)])
    verifyStream("[1, 2, 3, 4].stream.limit(1).collect", Obj?[n(1)])
    verifyStream("[1, 2, 3, 4].stream.limit(0).collect", Obj?[,])

    // skip
    verifyStream("[1, 2, 3, 4].stream.skip(0).collect", Obj?[n(1), n(2), n(3), n(4)])
    verifyStream("[1, 2, 3, 4].stream.skip(1).collect", Obj?[n(2), n(3), n(4)])
    verifyStream("[1, 2, 3, 4].stream.skip(2).collect", Obj?[n(3), n(4)])
    verifyStream("[1, 2, 3, 4].stream.skip(3).collect", Obj?[n(4)])
    verifyStream("[1, 2, 3, 4].stream.skip(4).collect", Obj?[,])
    verifyStream("[1, 2, 3, 4].stream.skip(5).collect", Obj?[,])
    verifyStream("[1, 2, 3, 4].stream.skip(1).limit(2).collect", Obj?[n(2), n(3)])

    // first
    verifyStream("[1, 2, 3, 4].stream.first", n(1))

    // last
    verifyStream("[1, 2, 3, 4].stream.last", n(4))
    verifyStream("[1, 2, 3, 4].stream.limit(2).last", n(2))

    // each
    verifyStream("do acc:[]; (2..4).stream.each(v => acc=acc.add(v)); acc; end", Obj?[n(2), n(3), n(4)])

    // eachWhile
    verifyStream(
     """do
          acc:[]
          r: (1..100).stream.eachWhile(v => do acc=acc.add(v); if (v >= 4) "break"; end)
          acc.add(r)
        end""", Obj?[n(1), n(2), n(3), n(4), "break"])

    // find
    verifyStream("[1, 2, 3, 4].stream.find(v=>isEven(v))", n(2))
    verifyStream("[1, 2, 3, 4].stream.find(v=>v > 100)", null)

    // any
    verifyStream("[1, 2, 3, 4].stream.any(v=>isEven(v))", true)
    verifyStream("[1, 2, 3, 4].stream.any(v=>v > 100)", false)

    // all
    verifyStream("[1, 2, 3, 4].stream.all(v=>isEven(v))", false)
    verifyStream("[1, 2, 3, 4].stream.all(v=>v > 0)", true)

    // reduce
    verifyStream("[1, 2, 3, 4].stream.reduce(0, (acc,val)=>acc+val)", n(10))
    verifyStream("[1, 2, 3, 4].stream.reduce(100, (acc,val)=>acc+val)", n(110))
    verifyStream("[1, 2, 3, 4].stream.reduce(0, (acc,val)=>acc*val)", n(0))
    verifyStream("[1, 2, 3, 4].stream.reduce(1, (acc,val)=>acc*val)", n(24))

    // fold
    verifyStream("[1, 2, 3, 4].stream.fold(count)", n(4))
    verifyStream("[1, 2, 3, 4].stream.fold(sum)", n(10))
    verifyStream("[1, 2, 3, 4].stream.fold(avg)", n(10f/4f))
    verifyStream("[1, 2, 3, 4].stream.fold(min)", n(1))
    verifyStream("[1, 2, 3, 4].stream.fold(max)", n(4))
    verifyStream("[1, 2, na(), 3, 4].stream.fold(count)", n(5))
    verifyStream("[1, 2, na(), 3, 4].stream.fold(sum)", NA.val)
    verifyStream("[1, 2, na(), 3, 4].stream.fold(avg)", NA.val)
    verifyStream("[1, 2, na(), 3, 4].stream.fold(min)", NA.val)
    verifyStream("[1, 2, na(), 3, 4].stream.fold(max)", NA.val)

    // streamCol
    verifyStream("[{v:1}, {v:2}, {v:3}].toGrid.streamCol(\"v\").fold(sum)", n(6))

    // complex
    verifyStream("[1, 2, 3, 4].stream.map(v=>v*2).limit(3).collect", Obj?[n(2), n(4), n(6)])
  }

//////////////////////////////////////////////////////////////////////////
// Grids
//////////////////////////////////////////////////////////////////////////

  Void testGrid()
  {
    zinc :=
      Str<|ver:"3.0" m1:"m-one"
           id,  dis,  a a1:"a-one", b b1:"b-one"
           @x,  "X",  "xa",         "xb"
           @yx, "Y",  "ya",         "yb"
           |>
    orig := ZincReader(zinc.in).readGrid

    // pass thru collect
    verifyGridStream(orig, ".collect", orig)

    // setMeta, addMeta
    verifyGridStream(orig, ".setMeta({m:123}).collect", orig.setMeta(["m":n(123)]))
    verifyGridStream(orig, ".addMeta({m:123}).collect", orig.addMeta(["m":n(123)]))
    verifyGridStream(orig, ".addMeta({m2:2}).addMeta({m3:3}).collect", orig.setMeta(["m1":"m-one", "m2":n(2), "m3":n(3)]))
    verifyGridStream(orig, ".setMeta({m2:2}).addMeta({m3:3}).collect", orig.setMeta(["m2":n(2), "m3":n(3)]))
    verifyGridStream(orig, ".setMeta({m2:2}).addMeta({m3:3}).setMeta({m4:4}).collect", orig.setMeta(["m4":n(4)]))
    verifyGridStream(orig, ".addMeta({-m1, m2:2}).collect", orig.setMeta(["m2":n(2)]))

    // setColMeta, addColMeta
    verifyGridStream(orig, """.addColMeta("x", {foo}).collect""", orig)
    verifyGridStream(orig, """.addColMeta("a", {a2:2}).collect""", orig.addColMeta("a", ["a2":n(2)]))
    verifyGridStream(orig, """.addColMeta("a", {a2:2}).addColMeta("a", {a3:3, -a1}).collect""", orig.setColMeta("a", ["a2":n(2), "a3":n(3)]))
    verifyGridStream(orig, """.setColMeta("a", {foo, bar}).collect""", orig.setColMeta("a", ["foo":m, "bar":m]))
    verifyGridStream(orig, """.addColMeta("a", {x}).setColMeta("a", {y}).addColMeta("a", {z}).collect""", orig.setColMeta("a", ["y":m, "z":m]))

    // removeCol, removeCols, keepCols, reorderCols
    verifyGridStream(orig, """.removeCol("x").collect""", orig)
    verifyGridStream(orig, """.removeCol("a").collect""", orig.removeCol("a"))
    verifyGridStream(orig, """.removeCols(["b", "a"]).collect""", orig.removeCols(["a", "b"]))
    verifyGridStream(orig, """.removeCol("b").removeCol("a").collect""", orig.removeCols(["a", "b"]))
    verifyGridStream(orig, """.removeCols(["b", "a", "x"]).collect""", orig.removeCols(["a", "b", "x"]))
    verifyGridStream(orig, """.keepCols(["dis", "id"]).collect""", orig.keepCols(["id", "dis"]))
    verifyGridStream(orig, """.reorderCols(["dis", "id"]).collect""", orig.reorderCols(["dis", "id"]))
    verifyGridStream(orig, """.reorderCols(["b", "dis", "id", "a", "x"]).collect""", orig.reorderCols(["b", "dis", "id", "a"]))
    verifyGridStream(orig, """.removeCols(["a", "b"]).keepCols(["b", "dis", "id", "a", "x"]).collect""", orig.keepCols(["id", "dis"]))
    verifyGridStream(orig, """.removeCols(["a", "dis"]).reorderCols(["b", "dis", "id", "a", "x"]).collect""", orig.reorderCols(["b", "id"]))

    // verify these infer grid
    verifyGridEq(eval("""[1, 2, 3].stream.setMeta({foo:123}).collect"""), Etc.makeListGrid(["foo":n(123)], "val", null, [n(1), n(2), n(3)]))
    verifyGridEq(eval("""[1, 2, 3].stream.addMeta({foo:123}).collect"""), Etc.makeListGrid(["foo":n(123)], "val", null, [n(1), n(2), n(3)]))
    verifyGridEq(eval("""[1, 2, 3].stream.setColMeta("val", {foo:123}).collect"""), Etc.makeListGrid(null, "val", ["foo":n(123)], [n(1), n(2), n(3)]))
    verifyGridEq(eval("""[1, 2, 3].stream.addColMeta("val", {foo:123}).collect"""), Etc.makeListGrid(null, "val", ["foo":n(123)], [n(1), n(2), n(3)]))
    verifyGridEq(eval("""[1, 2, 3].stream.removeCol("foo").collect"""), Etc.makeListGrid(null, "val", null, [n(1), n(2), n(3)]))
    verifyGridEq(eval("""[1, 2, 3].stream.removeCols(["foo"]).collect"""), Etc.makeListGrid(null, "val", null, [n(1), n(2), n(3)]))
    verifyGridEq(eval("""[1, 2, 3].stream.keepCols(["val", "x"]).collect"""), Etc.makeListGrid(null, "val", null, [n(1), n(2), n(3)]))
    verifyGridEq(eval("""[1, 2, 3].stream.reorderCols(["val", "x"]).collect"""), Etc.makeListGrid(null, "val", null, [n(1), n(2), n(3)]))

    // streamCol
    verifyStreamCol(orig, """.streamCol("id").collect""", Obj?[orig[0].id, orig[1].id])
    verifyStreamCol(orig, """.streamCol("dis").collect""", Obj?["X", "Y"])
  }

  Void verifyGridStream(Grid input, Str tail, Grid expected)
  {
    src := "(g) => stream(g)" + tail
    cx := makeContext
    actual := (Grid)cx.evalToFunc(src).call(cx, [input])
    verifyGridEq(actual, expected)

    // verify meta reused if not changed
    verifyGridMetaSame(input.meta, actual.meta)
    input.cols.each |ca|
    {
      cb := actual.col(ca.name, false)
      if (cb != null) verifyGridMetaSame(ca.meta, cb.meta)
    }
  }

  Void verifyGridMetaSame(Dict a, Dict b)
  {
    if (Etc.dictEq(a, b)) verifySame(a, b)
  }

  Void verifyStreamCol(Grid input, Str tail, Obj expected)
  {
    src := "(g) => g" + tail
    cx := makeContext
    actual := cx.evalToFunc(src).call(cx, [input])
    verifyValEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyStream(Str src, Obj? expected)
  {
    // verify normally
    verifyEval(src, expected)

    // don't try to round trip blocks
    if (src.endsWith("end")) return null

    // round trip encoding/decode and verify again
    actual := roundTripStream(makeContext, src)
    verifyEq(actual, expected)
  }

  ** Encode stream, decode it, and then re-evaluate it.
  ** The terminal expr cannot have a dot
  static Obj? roundTripStream(AxonContext cx, Str src)
  {

    // split out terminal step
    dot := src.indexr(".")
    head := src[0..<dot]    // upstream of terminal
    tail := src[dot+1..-1]  // terminal step

    // encode to stream to Zinc grid
    stream := (MStream)cx.eval(head)
    zinc := ZincWriter.gridToStr(stream.encode)

    // decode from Zinc back to grid, and back to MStream
    grid := ZincReader(zinc.in).readGrid
    stream = MStream.decode(cx, grid)

    // now re-evaluate terminal function with stream as first arg
    actual := cx.evalToFunc("(s)=>s.$tail").call(cx, [stream])
    return actual
  }

}