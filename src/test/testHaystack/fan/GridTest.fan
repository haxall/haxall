//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2009  Brian Frank  Creation
//

using xeto
using haystack

**
** GridTest
**
@Js
class GridTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    g := g(
      Str<|ver:"3.0"
           id, dis dis:"Display", num
           @a, "a", 1
           @b, "b", 2
           |>)

     // cols
     verifyEq(g.cols.size, 3)
     verifyEq(g.cols[0].name, "id")
     verifyEq(g.cols[1].name, "dis")
     verifyEq(g.cols[2].name, "num")
     verifyEq(g.colNames, ["id", "dis", "num"])
     verifyEq(g.colDisNames, ["id", "Display", "num"])

     // Row.dis
     verifyEq(g[1].dis, "b")
     verifyEq(g[1].dis("num"), "2")

     // conveniences
     verifyEq(g.ids, Ref[Ref("a"), Ref("b")])
     verifyEq(g.colToList("dis"), Obj?["a", "b"])
     verifyEq(g.colToList("dis", Str#), ["a", "b"])
   }

//////////////////////////////////////////////////////////////////////////
// Formatting
//////////////////////////////////////////////////////////////////////////

  Void testFormatting()
  {
    g := g(
      Str<|ver:"3.0"
           num format:"#.00", date format:"DD/MM/YYYY",time format:"hhmm",bool enum:"off,on"
           3,2013-09-03,13:45,T
           |>)

     verifyEq(g[0].dis("num"), "3.00")
     verifyEq(g[0].dis("date"), "03/09/2013")
     verifyEq(g[0].dis("time"), "1345")
     verifyEq(g[0].dis("bool"), "on")
   }

//////////////////////////////////////////////////////////////////////////
// EachWhile
//////////////////////////////////////////////////////////////////////////

  Void testEachWhile()
  {
    // original
    grid := g(
      Str<|ver:"3.0"
           a,   b
           "a", 0
           "b", 1
           "c", 2
           "d", 3
           |>)

    c := 0
    r := grid.eachWhile |row, i|
    {
      verifyEq(row->a, ('a'+i).toChar)
      verifyEq(row->b, n(i))
      ++c
      return null
    }
    verifyEq(r, null)
    verifyEq(c, 4)

    c = 0
    r = grid.eachWhile |row, i|
    {
      if (i == 2) return row->a
      return null
    }
    verifyEq(r, "c")
  }

//////////////////////////////////////////////////////////////////////////
// Any/All
//////////////////////////////////////////////////////////////////////////

  Void testAnyAll()
  {
    // original
    grid := g(
      Str<|ver:"3.0"
           a,   b
           "a", 10
           "b", 20
           "c", 30
           |>)

    verifyEq(grid.all { true }, true)
    verifyEq(grid.all { false }, false)
    verifyEq(grid.all |r, i| { r->a->size == 1 }, true)
    verifyEq(grid.all |r, i| { r->a->size == 2 }, false)
    verifyEq(grid.all |r, i| { r->b == n(20) }, false)

    verifyEq(grid.any { true }, true)
    verifyEq(grid.any{ false }, false)
    verifyEq(grid.any |r, i| { r->a->size == 1 }, true)
    verifyEq(grid.any |r, i| { r->a->size == 2 }, false)
    verifyEq(grid.any |r, i| { r->b == n(20) }, true)

    // any, all false
    c := 0
    r := grid.any |row, i|
    {
      verifyEq(row->a, ('a'+i).toChar)
      verifyEq(row->b, n(10+i*10))
      ++c
      return false
    }
    verifyEq(r, false)
    verifyEq(c, 3)

    // any, first true
    c = 0
    r = grid.any |row, i| { ++c; return true }
    verifyEq(r, true)
    verifyEq(c, 1)

    // all, all true
    c = 0
    r = grid.all |row, i|
    {
      verifyEq(row->a, ('a'+i).toChar)
      verifyEq(row->b, n(10+i*10))
      ++c
      return true
    }
    verifyEq(r, true)
    verifyEq(c, 3)

    // all, first false
    c = 0
    r = grid.all |row, i| { ++c; return false }
    verifyEq(r, false)
    verifyEq(c, 1)
  }

//////////////////////////////////////////////////////////////////////////
// Sort
//////////////////////////////////////////////////////////////////////////

  Void testSort()
  {
    grid := g(
      Str<|ver:"3.0" foo:"bar"
           name,   b
           "a",    10
           "b",    4
           "c",    3
           "d",    2
           "d-9",  5
           "d-10", 6
           |>)

    verifySort(grid.sortCol("b"), ["d", "c", "b", "d-9", "d-10", "a"])
    verifySort(grid.sortCol(grid.col("b")), ["d", "c", "b", "d-9", "d-10", "a"])
    verifySort(grid.sortCol("name"), ["a", "b", "c", "d", "d-10", "d-9"])
    verifySort(grid.sortDis, ["a", "b", "c", "d", "d-9", "d-10"])
  }

  Void verifySort(Grid grid, Str[] names)
  {
    verifyEq(grid.meta->foo, "bar")
    verifyEq(grid.size, 6)
    verifyEq(grid.col("name").name, "name")
    i := 0
    grid.each |row|
    {
      verifySame(row.grid, grid)
      verifyEq(row->name, names[i++])
    }
  }

//////////////////////////////////////////////////////////////////////////
// Find/FindAll
//////////////////////////////////////////////////////////////////////////

  Void testFindAll()
  {
    // original
    grid := g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d
           "a",  1,     N
           "b",  4,     N
           "c",  3,     N
           "d",  2,     N
           |>)

    verifySame(grid.find |row| { row->c->toInt->isEven }, grid[1])
    verifySame(grid.find |row| { row->a == "d" }, grid[3])
    verifyEq(grid.findIndex |row| { row->a == "d" }, 3)
    verifyEq(grid.findIndex |row| { row->a == "z" }, null)
    verifyEq(grid.find |row| { false }, null)

    r := grid.findAll |row| { row->c->toInt->isOdd }

    verifyGridEq(r, g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d
           "a",  1,     N
           "c",  3,     N
           |>))

    r = grid.filter(Filter("c >= 3"))

    verifyGridEq(r, g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d
           "b",  4,     N
           "c",  3,     N
           |>))
  }

//////////////////////////////////////////////////////////////////////////
// Map
//////////////////////////////////////////////////////////////////////////

  Void testMap()
  {
    // original
    grid := g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d
           "a",  1,     N
           "b",  4,     N
           "c",  3,     N
           "d",  2,     N
           |>)

    map := grid.map |row|
    {
      tags := Str:Obj[:]
      tags.ordered = true
      tags["a"] = row->a
      tags["b"] = row->a->upper
      tags["c"] = Number(100f) + row->c
      return Etc.makeDict(tags)
    }

    list := grid.mapToList |r->Str| { r->a }
    verifyEq(list.typeof, Str[]#)
    verifyEq(list, ["a", "b", "c", "d"])
    list = grid.mapToList |r, i| { i.isEven ? r["c"] : r["d"] }
    verifyEq(list.typeof, Obj?[]#)
    verifyEq(list, Obj?[n(1), null, n(3), null])

    verifyGridEq(map, g(
      Str<|ver:"3.0" foo:"bar"
           a f,  b,    c dis:"C"
           "a",  "A",  101
           "b",  "B",  104
           "c",  "C",  103
           "d",  "D",  102|>))

    // sanity check for GridBuilder.addDictRow optimization
    gb := GridBuilder()
    gb.addCol("c").addCol("b").addCol("a")
    map.each |row| { gb.addDictRow(row) }
    x := gb.toGrid
    verifyGridEq(x, g(
      Str<|ver:"3.0"
           c,   b,    a
           101, "A",  "a"
           104, "B",  "b"
           103, "C",  "c"
           102, "D",  "d"|>))

     // verify empty grid maps to itself
     empty := GridBuilder().setMeta(["foo":m]).addCol("bar", ["baz":m]).toGrid
     verifySame(empty.map |r| { Etc.dict1("wrong", m) }, empty)
     verifySame(empty.flatMap |r| { Dict[,] }, empty)
  }

//////////////////////////////////////////////////////////////////////////
// FlatMap
//////////////////////////////////////////////////////////////////////////

  Void testFlatMap()
  {
    // original
    grid := g(
      Str<|ver:"3.0" foo:"bar"
           a foo,  b
           "a",    1
           "b",    4
           |>)

    map := grid.flatMap |row|
    {
      tags := Str:Obj[:]
      tags.ordered = true
      tags["a"] = row->a
      tags["au"] = row->a->upper
      tags["c"] = Number(100f) + row->b
      x := Etc.makeDict(tags)

      tags = Str:Obj[:]
      tags.ordered = true
      tags["a"] = "_" + row->a
      tags["d"] = row->b
      y := Etc.makeDict(tags)

      return [x, null, y]
    }

    verifyGridEq(map, g(
      Str<|ver:"3.0" foo:"bar"
           a foo,  au,   c,   d
           "a",    "A",  101, N
           "_a",     N,    N, 1
           "b",    "B",  104, N
           "_b",     N,   N,  4
           |>))
  }

//////////////////////////////////////////////////////////////////////////
// Replace
//////////////////////////////////////////////////////////////////////////

  Void testReplace()
  {
    // original
    grid := g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d,  e
           "a",  1,         N,  NA
           "b",  4,         N,  "a"
           "c",  N,         N,  "a"
           "d",  2,         4,  NA
           |>)

    a := grid.replace(null, n(0))
    verifyGridEq(a, g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d,  e
           "a",  1,         0,  NA
           "b",  4,         0,  "a"
           "c",  0,         0,  "a"
           "d",  2,         4,  NA
           |>))

    a = grid.replace(n(4), null)
    verifyGridEq(a, g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d,  e
           "a",  1,         N,  NA
           "b",  N,         N,  "a"
           "c",  N,         N,  "a"
           "d",  2,         N,  NA
           |>))

    a = grid.replace(NA.val, "-")
    verifyGridEq(a, g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d,  e
           "a",  1,         N,  "-"
           "b",  4,         N,  "a"
           "c",  N,         N,  "a"
           "d",  2,         4,  "-"
           |>))

    a = grid.replace("a", "!")
    verifyGridEq(a, g(
      Str<|ver:"3.0" foo:"bar"
           a f,  c dis:"C", d,  e
           "!",  1,         N,  NA
           "b",  4,         N,  "!"
           "c",  N,         N,  "!"
           "d",  2,         4,  NA
           |>))
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  Void testCommit()
  {
    // original
    grid := g(
      Str<|ver:"3.0" foo
           a dis:"A", b bar
           1, 2
           3, 4|>)

    // set b; add c,d
    grid = grid.commit(g(
      Str<|ver:"3.0" commit:"update"
           b, c, d
           20, 1min, "1"
           40, 2min, "2"|>))

    // verify
    verifyGridEq(grid, g(
      Str<|ver:"3.0" foo
           a dis:"A", b bar, c, d
           1, 20, 1min, "1"
           3, 40, 2min, "2"|>))

    // set b partial; set/remove c; remove d; add e
    grid = grid.commit(g(
      Str<|ver:"3.0" commit:"update"
           b,   c,      d,      e
           200, 10min,  R, -1
           ,    R,      R, -2|>))

    // verify
    verifyGridEq(grid, g(
      Str<|ver:"3.0" foo
           a dis:"A", b bar,  c,     e
           1,     200,    10min, -1
           3,     40,     ,      -2|>))
  }

//////////////////////////////////////////////////////////////////////////
// Join
//////////////////////////////////////////////////////////////////////////

  Void testJoin()
  {
    g1 := g(
      Str<|ver:"3.0" m1:1 m2:2
           a,   b dis:"B" mb1, c mc
           "a", 1,         10
           "c", 3,         30
           "d", 4,         40
           |>)

    g2 := g(
      Str<|ver:"3.0" m2:20 m3:3
           d md, b mb2, e dis:"E"
           "A",  1,     1ms
           "B",  2,     2ms
           "C",  3,     3ms
           "E",  5,     5ms
           |>)

    byB := g(
      Str<|ver:"3.0" m1:1 m2:20 m3:3
           a,    b dis:"B" mb1 mb2, c mc, d md, e dis:"E"
           "a",  1,  10,  "A",  1ms
           "c",  3,  30,  "C",  3ms
           "d",  4,  40,  N,    N
           N,    2,  N,   "B",  2ms
           N,    5,  N,   "E",  5ms
           |>)
    r := g1.join(g2, "b"); verifyGridEq(r, byB)
    verifyGridEq(g1.join(g2, g1.col("b")), byB)
    verifyGridEq(g1.join(g2, g2.col("b")), byB)

    g3 := g(
      Str<|ver:"3.0"
           b, f
           1, 100
           2, 200
           3, 300
           |>)

    r = r.join(g3, "b")
    verifyGridEq(r, g(
      Str<|ver:"3.0" m1:1 m2:20 m3:3
           a,    b dis:"B" mb1 mb2, c mc, d md, e dis:"E", f
           "a",  1,  10,  "A",  1ms, 100
           "c",  3,  30,  "C",  3ms, 300
           "d",  4,  40,  N,    N,   N
           N,    2,  N,   "B",  2ms, 200
           N,    5,  N,   "E",  5ms, N
           |>))
  }

//////////////////////////////////////////////////////////////////////////
// Views
//////////////////////////////////////////////////////////////////////////

  Void testViews()
  {
    x := g(
      Str<|ver:"3.0" m1:1 m2:2
           a,   b dis:"B" mb,  c mc
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>)

    // Grid.addMeta
    x = x.addMeta(Etc.makeDict(["m2":n(20), "m3":n(30)]))
    verifyGridEq(x, g(
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           a,   b dis:"B" mb,  c mc
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>))

    // Grid.setMeta
    x = x.setMeta(Etc.makeDict(["m2":n(20), "m3":n(30), "m4":n(40)]))
    verifyGridEq(x, g(
      Str<|ver:"3.0" m2:20 m3:30 m4:40
           a,   b dis:"B" mb,  c mc
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>))

    // Grid.addMeta again with remove
    x = x.addMeta(Etc.makeDict(["m1":n(1), "m4":Remove.val]))
    verifyGridEq(x, g(
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           a,   b dis:"B" mb,  c mc
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>))

    // Grid.addColMeta
    x = verifyView(x,
      |Grid g->Grid| { g.addColMeta("c", Etc.makeDict(["foo":Marker.val])) },
      |Grid g->Grid| { g.addColMeta(g.col("c"), Etc.makeDict(["foo":Marker.val])) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           a,   b dis:"B" mb, c mc foo
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>)

    // Grid.setColMeta
    x = verifyView(x,
      |Grid g->Grid| { g.setColMeta("c", Etc.makeDict(["bar":Marker.val])) },
      |Grid g->Grid| { g.setColMeta(g.col("c"), Etc.makeDict(["bar":Marker.val])) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           a,   b dis:"B" mb, c bar
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>)

    // Grid.addColMeta with remove
    x = verifyView(x,
      |Grid g->Grid| { g.addColMeta("c", Etc.makeDict(["mc":Marker.val, "foo":Marker.val, "bar":Remove.val])) },
      |Grid g->Grid| { g.addColMeta(g.col("c"), Etc.makeDict(["mc":Marker.val, "foo":Marker.val, "bar":Remove.val])) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           a,   b dis:"B" mb, c mc foo
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>)

    // Grid.renameCol
    x = verifyView(x,
      |Grid g->Grid| { g.renameCol("b", "boo") },
      |Grid g->Grid| { g.renameCol(g.col("b"), "boo") },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           a,   boo dis:"B" mb,  c mc foo
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>)

    // Grid.renameCols
    x = verifyView(x,
      |Grid g->Grid| { g.renameCols(["a":"ax", "boo":"bx", "notThere":"xxx"]) },
      |Grid g->Grid| { g.renameCols([g.col("a"):"ax", g.col("boo"):"bx", "notThere":"xxx"]) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           ax,  bx dis:"B" mb,  c mc foo
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>)

    // Grid.addCol
    x = x.addCol("d",
      Etc.makeDict(["dis":"D", "md":Marker.val])) { n(100f, Unit("kg")) + n(it->c->toFloat) }
    verifyGridEq(x, g(
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           ax,  bx dis:"B" mb,  c mc foo, d dis:"D" md
           "a", @1 "_1", 10ms, 110kg
           "b", @2 "_2", 20ms, 120kg
           |>))

    // Grid.reorderCols
    x = verifyView(x,
      |Grid g->Grid| { g.reorderCols(["bx", "ax", "d", "c"]) },
      |Grid g->Grid| { g.reorderCols([g.col("bx"), g.col("ax"), g.col("d"), g.col("c")]) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           bx dis:"B" mb, ax, d dis:"D" md, c mc foo
           @1 "_1", "a", 110kg, 10ms
           @2 "_2", "b", 120kg, 20ms
           |>)
    x = x.reorderCols(["ax", "bx", "d", "c"])

    // Grid.removeCol(s)
    x = verifyView(x,
      |Grid g->Grid| { g.removeCol("d") },
      |Grid g->Grid| { g.removeCol(g.col("d")) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           ax,  bx dis:"B" mb,  c mc foo
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           |>)

    // Grid.removeCols
    x = verifyView(x,
      |Grid g->Grid| { g.removeCols(["ax", "c", "notThere"]) },
      |Grid g->Grid| { g.removeCols([g.col("ax"), g.col("c")]) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           bx dis:"B" mb
           @1 "_1"
           @2 "_2"
           |>)

    // Grid.keepCols
    x = verifyView(x,
      |Grid g->Grid| { g.keepCols(["bx", "notThere"]) },
      |Grid g->Grid| { g.keepCols([g.col("bx")]) },
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           bx dis:"B" mb
           @1 "_1"
           @2 "_2"
           |>)

    // Grid.addCols
    verifyGridEq(x.addCols(x), g(
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           bx dis:"B" mb, bx_1 dis:"B" mb,
           @1 "_1",@1 "_1"
           @2 "_2",@2 "_2"
           |>))

    // Grid.addCols w/ sparse cells
    verifyGridEq(x.addCols(Etc.makeMapGrid(Etc.dict1("foo", Marker.val), ["x":n(1), "y":n(2)])), g(
      Str<|ver:"3.0" m1:1 m2:20 m3:30
           bx mb dis:"B",x,y
           @1 "_1",1,2
           @2 "_2",,
           |>))
  }

  Grid verifyView(Grid x, |Grid g->Grid| a, |Grid->Grid| b, Str expected)
  {
    expectedGrid := g(expected)
    ra := a(x); verifyGridEq(ra, expectedGrid)
    rb := b(x); verifyGridEq(rb, expectedGrid)
    verifySame(ra.toConst, ra); verifyEq(ra.isImmutable, true)
    verifySame(rb.toConst, rb); verifyEq(rb.isImmutable, true)
    return Date.today.day.isOdd ? ra : rb
  }

//////////////////////////////////////////////////////////////////////////
// Slice
//////////////////////////////////////////////////////////////////////////

  Void testSlice()
  {
    x := g(
      Str<|ver:"3.0" m1:1 m2:2
           a,   b dis:"B" mb,  c mc
           "a", @1 "_1", 10ms
           "b", @2 "_2", 20ms
           "c", @3 "_3", 30ms
           "d", @4 "_4", 40ms
           |>)

    // Grid.getRange
    verifyGridEq(x[0..0], g(
      Str<|ver:"3.0" m1:1 m2:2
           a,   b dis:"B" mb,  c mc
           "a", @1 "_1", 10ms
           |>))

    verifyGridEq(x[2..-1], g(
      Str<|ver:"3.0" m1:1 m2:2
           a,   b dis:"B" mb,  c mc
           "c", @3 "_3", 30ms
           "d", @4 "_4", 40ms
           |>))
  }

//////////////////////////////////////////////////////////////////////////
// Transpose
//////////////////////////////////////////////////////////////////////////

  Void testTranspose()
  {
    Grid src := g(
      Str<|ver:"3.0" m:"!"
           dis dis:"Display",x dis:"Beta",y
           "foo","Foo",12
           "bar",N,M
           |>)

    r := src.transpose

    verifyGridEq(r, g(
      Str<|ver:"3.0" m:"!"
           dis transposedDis:"Display", v0 dis:"foo",v1 dis:"bar"
           "Beta","Foo",N
           "y",12,M
           |>))
  }

//////////////////////////////////////////////////////////////////////////
// GbHisItem
//////////////////////////////////////////////////////////////////////////

  Void testGbHisItems()
  {
    ts := |Str s->DateTime| { DateTime.fromLocale(s, "YY-MM-DD hh:mm", TimeZone.cur) }
    items := |Str s, Int? v->HisItem| { HisItem(ts(s), v == null ? null : n(v)) }

    // zero val cols
    gb := GridBuilder()
    gb.addCol("ts")
    gb.addHisItemRows(HisItem[][,])
    verifyGbHisItems(gb.toGrid, [,])

    // one val cols
    gb = GridBuilder()
    gb.addCol("ts").addCol("v0")
    v0 := [
      items("16-07-11 00:05",  5),
      items("16-07-11 00:10", 10),
      items("16-07-11 00:15", 15),
      items("16-07-11 00:20", 20),
    ]
    gb.addHisItemRows([v0])

    verifyGbHisItems(gb.toGrid, [
      [ts("16-07-11 00:05"), n(5)],
      [ts("16-07-11 00:10"), n(10)],
      [ts("16-07-11 00:15"), n(15)],
      [ts("16-07-11 00:20"), n(20)],
      ])

    // two val cols perfectly aligned
    gb = GridBuilder()
    gb.addCol("ts").addCol("v0").addCol("v1")
    v1 := [
      items("16-07-11 00:05", 105),
      items("16-07-11 00:10", 110),
      items("16-07-11 00:15", 115),
      items("16-07-11 00:20", 120),
    ]
    gb.addHisItemRows([v0, v1])

    verifyGbHisItems(gb.toGrid, [
      [ts("16-07-11 00:05"),  n(5), n(105)],
      [ts("16-07-11 00:10"), n(10), n(110)],
      [ts("16-07-11 00:15"), n(15), n(115)],
      [ts("16-07-11 00:20"), n(20), n(120)],
      ])

    // three unaligned value cols
    gb = GridBuilder()
    gb.addCol("ts").addCol("v0").addCol("v1").addCol("v2")
    v2 := [
      items("16-07-11 00:00", 200),
      items("16-07-11 00:01", 201),
      items("16-07-11 00:06", 206),
      items("16-07-11 00:14", 214),
      items("16-07-11 00:15", 216),
      items("16-07-11 00:21", 221),
    ]
    gb.addHisItemRows([v0, v1, v2])

    // four unaligned value cols
    gb = GridBuilder()
    gb.addCol("ts").addCol("v0").addCol("v1").addCol("v2").addCol("v3")
    v3 := [
      items("16-07-10 23:00", 323),
      items("16-07-11 00:01", 301),
      items("16-07-11 00:02", 302),
      items("16-07-11 00:03", null),
      items("16-07-11 00:10", 310),
      items("16-07-11 00:20", 320),
      items("16-07-11 00:21", 321),
    ]
    gb.addHisItemRows([v0, v1, v2, v3])

    verifyGbHisItems(gb.toGrid, [
      [ts("16-07-10 23:00"),  null,   null,   null, n(323)],
      [ts("16-07-11 00:00"),  null,   null, n(200),   null],
      [ts("16-07-11 00:01"),  null,   null, n(201), n(301)],
      [ts("16-07-11 00:02"),  null,   null,   null, n(302)],
      [ts("16-07-11 00:03"),  null,   null,   null,   null],
      [ts("16-07-11 00:05"),  n(5), n(105),   null,   null],
      [ts("16-07-11 00:06"),  null,   null, n(206),   null],
      [ts("16-07-11 00:10"), n(10), n(110),   null, n(310)],
      [ts("16-07-11 00:14"),  null,   null, n(214),   null],
      [ts("16-07-11 00:15"), n(15), n(115), n(216),   null],
      [ts("16-07-11 00:20"), n(20), n(120),   null, n(320)],
      [ts("16-07-11 00:21"),  null,   null, n(221), n(321)],
      ])
  }

  Void verifyGbHisItems(Grid g, Obj?[][] expected)
  {
    verifyEq(g.size, expected.size)
    g.each |row, i|
    {
      expectedRow := expected[i].findNotNull
      j := 0
      row.each |val|
      {
        verifyEq(val, expectedRow[j++])
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Grid g(Str str)
  {
    g := ZincReader(str.in).readGrid
    verifySame(g.toConst, g)
    verifyEq(g.isImmutable, true)
    return g
  }

}

