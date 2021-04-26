//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2009  Brian Frank  Creation
//

using haystack

**
** ZincTest
**
@Js
class ZincTest : HaystackTest
{
  Void test()
  {
    // 1x0
    verifyGrid(
      Str<|ver:"2.0"
           fooBar33
           |>,
      Str:Obj?[:],
      [tc("fooBar33")],
      [,])

    // 1x1
    verifyGrid(
      Str<|ver:"2.0" tag foo:"bar"
           xyz
           "val"
           |>,
      ["tag":Marker.val, "foo":"bar"],
      [tc("xyz")],
      [["val"]])

    // 1x1 null
    verifyGrid(
      Str<|ver:"2.0"
           val
           N
           |>,
      Str:Obj?[:],
      [tc("val")],
      [[null]])

    // 2x2
    verifyGrid(
      Str<|ver:"2.0"
           a,b
           1,2
           3,4
           |>,
      Str:Obj?[:],
      [tc("a"), tc("b")],
      [[n(1), n(2)],
       [n(3), n(4)]])

    // bins
    verifyGrid(
      Str<|ver:"2.0" bg: Bin(image/jpeg) mark
           file1 dis:"F1" icon: Bin(image/gif),file2 icon: Bin(image/jpg)
           Bin(text/plain),N
           4,Bin(image/png)
           Bin(text/html; a=foo; bar=sep),Bin(text/html; charset=utf8)|>,
      ["bg":Bin("image/jpeg"), "mark":Marker.val],
      [tc("file1", ["dis":"F1", "icon":Bin("image/gif")]), tc("file2", ["icon":Bin("image/jpg")])],
      [[Bin("text/plain"), null],
       [n(4), Bin("image/png")],
       [Bin("text/html;a=foo;bar=sep"), Bin("text/html;charset=utf8")]])

    // all scalars
    verifyGrid(
      Str<|ver:"2.0"
           a,    b,      c,      d
           T,    F,      N,   -99
           2.3,  -5e-10, 2.4e20, 123e-10
           "",   "a",   "\" \\ \t \n \r", "\uabcd"
           `path`, @12cbb082-0c02ae73, 4s, -2.5min
           M,R,Bin(image/png),Bin(image/png)
           2009-12-31, 23:59:01, 01:02:03.123, 2009-02-03T04:05:06Z
           INF, -INF, "", NaN
           C(12,-34),C(0.123,-0.789),C(84.5,-77.45),C(-90,180)
           NA,N,^a:b,"foo"
           |>,
      Str:Obj?[:],
      [tc("a"), tc("b"), tc("c"), tc("d")],
      [[true, false, null, n(-99)],
       [n(2.3f), n(-5e-10f), n(2.4e20f), n(123e-10f)],
       ["", "a", "\" \\ \t \n \r", "\uabcd"],
       [`path`, Ref("12cbb082-0c02ae73"), n(4, "s"), n(-2.5f, "min")],
       [Marker.val, Remove.val, Bin("image/png"), Bin("image/png")], // strip bin meta
       [Date("2009-12-31"), Time("23:59:01"), Time("01:02:03.123"), DateTime("2009-02-03T04:05:06Z UTC")],
       [Number.posInf, Number.negInf, "", Number.nan],
       [Coord(12f,-34f), Coord(0.123f,-0.789f),Coord(84.5f,-77.45f), Coord(-90f,180f)],
       [NA.val,null,Symbol("a:b"),"foo"]])

    // specials
    verifyGrid(
      Str<|ver:"2.0"
           foo
           `foo$20bar`
           `foo\`bar`
           `file \#2`
           "$15"|>,
      Str:Obj?[:],
      [tc("foo")],
      [[`foo\$20bar`],
       [`foo\`bar`],
       [`file \#2`],
       ["\$15"]])

    // units
    verifyGrid(
      Str<|ver:"2.0"
           a, b
           -3.1kg,4kg
           5%,3.2%
           5kWh/ft²,-15kWh/m²
           123e+12kJ/kg_dry,74Δ°F|>,
      Str:Obj?[:],
      [tc("a"), tc("b")],
      [[n(-3.1f, "kilogram"), n(4, "kilogram")],
       [n(5, "%"), n(3.2f, "%")],
       [n(5, "kilowatt_hours_per_square_foot"), n(-15, "kilowatt_hours_per_square_meter")],
       [n(123e12f, "kilojoules_per_kilogram_dry_air"), n(74, "fahrenheit_degrees")]])

    // xstr
    verifyGrid(
      Str<|ver:"2.0"
           a,b
           Foo("foo"),C("")
           Bin("image/svg"),B("b\n)!")
           Span("2016-01-10"),Color("#fff")|>,
      Str:Obj?[:],
      [tc("a"), tc("b")],
      [[XStr("Foo", "foo"), XStr("C", "")],
       [Bin("image/svg"), XStr("B", "b\n)!")],
       [Span("2016-01-10"), XStr("Color", "#fff")],
       ])

    // sparse
    verifyGrid(
      Str<|ver:"2.0"
           a, b, c
           , 1, 2
           3, , 5
           6, 7_000,
           ,,10
           ,,
           14,,
           |>,
      Str:Obj?[:],
      [tc("a"), tc("b"), tc("c")],
      [[null, n(1), n(2)],
       [n(3), null, n(5)],
       [n(6), n(7_000), null],
       [null, null, n(10)],
       [null, null, null],
       [n(14), null, null]])

    // sparse
    verifyGrid(
      Str<|ver:"2.0"
           a,b
           2010-03-01T23:55:00.013-05:00 GMT+5,2010-03-01T23:55:00.013+10:00 GMT-10|>,
      Str:Obj?[:],
      [tc("a"), tc("b")],
      [[DateTime.fromStr("2010-03-01T23:55:00.013-05:00 GMT+5"),
        DateTime.fromStr("2010-03-01T23:55:00.013+10:00 GMT-10")]])

    // timezones and regression bugs
    verifyGrid(
      Str<|ver:"2.0" a: 2009-02-03T04:05:06Z foo b: 2010-02-03T04:05:06Z UTC bar c: 2009-12-03T04:05:06Z London baz
           a
           3.814697265625E-6
           2010-12-18T14:11:30.924Z
           2010-12-18T14:11:30.925Z UTC
           2010-12-18T14:11:30.925Z London
           2015-01-02T06:13:38.701-08:00 PST8PDT
           45$
           33£
           @12cbb08e-0c02ae73
           7.15625E-4kWh/ft²|>,
      Str:Obj?["a": DateTime("2009-02-03T04:05:06Z UTC"), "foo":Marker.val,
               "b": DateTime("2010-02-03T04:05:06Z UTC"), "bar": Marker.val,
               "c": DateTime("2009-12-03T04:05:06Z London"), "baz": Marker.val],
      [tc("a")],
      [
        [n(3.814697265625E-6f)],
        [DateTime("2010-12-18T14:11:30.924Z UTC")],
        [DateTime("2010-12-18T14:11:30.925Z UTC")],
        [DateTime("2010-12-18T14:11:30.925Z London")],
        [DateTime("2015-01-02T06:13:38.701-08:00 PST8PDT")],
        [n(45, "USD")],
        [n(33, "GBP")],
        [Ref("12cbb08e-0c02ae73")],
        [n(7.15625E-4f, "kWh/ft²")],
      ])
  }

//////////////////////////////////////////////////////////////////////////
// Nested
//////////////////////////////////////////////////////////////////////////

  Void testNested()
  {
    // simple one grid
    verifyGrid(
      Str<|ver:"2.0"
           val
           <<
           ver:"2.0"
           x,y
           4,6

           >>
           "foo"|>,
      Str:Obj?[:],
      [tc("val")],
      [
        [Etc.makeListsGrid(null, ["x", "y"], null, [[n(4),n(6)]])],
        ["foo"],
      ])

    // one col, two rows of grids
    verifyGrid(
      Str<|ver:"2.0"
           val
           <<
           ver:"2.0"
           x,y
           4,6

           >>
           <<
           ver:"2.0" foo
           z
           1
           2

           >>|>,
      Str:Obj?[:],
      [tc("val")],
      [
        [Etc.makeListsGrid(null, ["x", "y"], null, [[n(4),n(6)]])],
        [Etc.makeListsGrid(["foo":Marker.val], ["z"], null, [[n(1)],[n(2)]])],
      ])

    // two cols of grids
    verifyGrid(
      Str<|ver:"2.0"
           col1,col2
           <<
           ver:"2.0"
           x,y
           4,6

           >>,<<
           ver:"2.0" foo
           z
           1
           2

           >>|>,
      Str:Obj?[:],
      [tc("col1"),tc("col2")],
      [
        [Etc.makeListsGrid(null, ["x", "y"], null, [[n(4),n(6)]]), Etc.makeListsGrid(["foo":Marker.val], ["z"], null, [[n(1)],[n(2)]])],
      ])

    // 3x2 of grids
    verifyGrid(
      Str<|ver:"2.0"
           col1,col2,col3
           <<
           ver:"2.0"
           a
           1

           >>,<<
           ver:"2.0"
           b
           1

           >>,<<
           ver:"2.0"
           c
           1

           >>
           <<
           ver:"2.0"
           a
           2

           >>,<<
           ver:"2.0"
           b
           2

           >>,<<
           ver:"2.0"
           c
           2

           >>|>,
      Str:Obj?[:],
      [tc("col1"),tc("col2"),tc("col3")],
      [
        [ Etc.makeListsGrid(null, ["a"], null, [[n(1)]]), Etc.makeListsGrid(null, ["b"], null, [[n(1)]]),Etc.makeListsGrid(null, ["c"], null, [[n(1)]]) ],
        [ Etc.makeListsGrid(null, ["a"], null, [[n(2)]]), Etc.makeListsGrid(null, ["b"], null, [[n(2)]]),Etc.makeListsGrid(null, ["c"], null, [[n(2)]]) ],
      ])

    // double nesting
    verifyGrid(
      Str<|ver:"2.0"
           outer
           <<
           ver:"2.0"
           inner
           <<
           ver:"2.0"
           x
           1

           >>
           <<
           ver:"2.0"
           y
           2

           >>

           >>|>,
      Str:Obj?[:],
      [tc("outer")],
      [
        [
          Etc.makeListGrid(null, "inner", null,
          [ Etc.makeListsGrid(null, ["x"], null, [[n(1)]]),
            Etc.makeListsGrid(null, ["y"], null, [[n(2)]])
          ])
        ]
      ])
  }

//////////////////////////////////////////////////////////////////////////
// Errors
//////////////////////////////////////////////////////////////////////////

  Void testErrs()
  {
    verifyZincErr("sys::ParseErr: Invalid empty Ref [line 3]",
      Str<|ver:"2.0"
           foo
           @
           |>)

    verifyZincErr("sys::ParseErr: Invalid empty Ref [line 3]",
      Str<|ver:"2.0"
           foo
           @@
           |>)
  }

  Void verifyZincErr(Str msg, Str zinc)
  {
    try
    {
      g := ZincReader(zinc.in).readGrid
      fail
    }
    catch (Err e)
    {
      verifyEq(e.toStr, msg)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Version 2.0
//////////////////////////////////////////////////////////////////////////

  Void testVer2()
  {
    // bins 2.0
    verifyGrid(
      Str<|ver:"2.0" bg: Bin(image/jpeg) mark
           file1 dis:"F1" icon: Bin(image/gif),file2 icon: Bin(image/jpg)
           Bin(text/plain),N
           4,Bin(image/png)
           5,Bin(application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)
           Bin(text/html; a=foo; bar=sep),Bin(text/html; charset=utf8)|>,
      ["bg":Bin("image/jpeg"), "mark":Marker.val],
      [tc("file1", ["dis":"F1", "icon":Bin("image/gif")]), tc("file2", ["icon":Bin("image/jpg")])],
      [[Bin("text/plain"), null],
       [n(4), Bin("image/png")],
       [n(5), Bin("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")],
       [Bin("text/html;a=foo;bar=sep"), Bin("text/html;charset=utf8")]])

    // bins 3.0
    verifyGrid(
      Str<|ver:"3.0" bg: Bin("image/jpeg") mark
           file1 dis:"F1" icon: Bin("image/gif"),file2 icon: Bin("image/jpg")
           Bin("text/plain"),N
           4,Bin("image/png")
           5,Bin("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
           Bin("text/html; a=foo; bar=sep"),Bin("text/html; charset=utf8")|>,
      ["bg":Bin("image/jpeg"), "mark":Marker.val],
      [tc("file1", ["dis":"F1", "icon":Bin("image/gif")]), tc("file2", ["icon":Bin("image/jpg")])],
      [[Bin("text/plain"), null],
       [n(4), Bin("image/png")],
       [n(5), Bin("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")],
       [Bin("text/html; a=foo; bar=sep"), Bin("text/html; charset=utf8")]])

    // write bins 2.0
    /*
    s := StrBuf()
    w := ZincWriter(s.out)
    w.writeVal(Bin("text/plain; charset=utf8"))
    verifyEq(s.toStr, Str<|Bin(text/plain; charset=utf8)|>)
    */

    // write bins 3.0
    s := StrBuf()
    w := ZincWriter(s.out)
    w.writeVal(Bin("text/plain; charset=utf8"))
    verifyEq(s.toStr, Str<|Bin("text/plain; charset=utf8")|>)
  }

//////////////////////////////////////////////////////////////////////////
// Test Version 1.0
//////////////////////////////////////////////////////////////////////////

  /* NO LONGER SUPPORTED
  Void testVer1()
  {
    // 1.0 with old RecId syntax
    verifyGrid(
      Str<|ver:"1.0"
           id
           17eb1385-bffd1862
           |>,
      Str:Obj?[:],
      [tc("id")],
      [[Ref("17eb1385-bffd1862")]])

    // verify old RecId syntax with 2.0 fails
    verifyErr(Err#)
    {
      ZincReader(
        Str<|ver:"2.0"
             id
             17eb1385-bffd1862
             |>.in).readGrid
    }

    // cell dis and tags
    str := Str<|ver:"1.0" filter : "cool" age: 10sec
                a dis:"Alpha", b foo:"bar", c, d dis:"Delta" enabled:T
                1 "one",2 mark,3,4 "four"
                1 a:99,2,3 "three\u0abc",4 mark|>
    verifyGrid(str, ["filter": "cool", "age":n(10, "second")],
               [tc("a", ["dis":"Alpha"]), tc("b", ["foo":"bar"]), tc("c"), tc("d", ["dis":"Delta", "enabled":true])],
               [[n(1), n(2), n(3), n(4)],
                [n(1), n(2), n(3), n(4)]])
    verifyErr(Err#) { ZincReader(str.replace("1.0", "2.0").in).readGrid }

    // bins
    str = Str<|ver:"1.0" mark
               file1,file2
               Bin mime:"text/plain",N
               4,Bin mime:"image/png" foo:3
               Bin mime:"text/html" y,Bin mime:"text/html; charset=utf8"|>
    verifyGrid(str, ["mark":Marker.val],
               [tc("file1"), tc("file2")],
               [[Bin("text/plain"), null],
                [n(4), Bin("image/png")],
                [Bin("text/html"), Bin("text/html; charset=utf8")]])
    verifyErr(Err#) { ZincReader(str.replace("1.0", "2.0").in).readGrid }

    // 1.0 with column display
    verifyGrid(
      Str<|ver:"1.0"
           id "display",price "Price" unit:"$"
           "foo",40$
           |>,
      Str:Obj?[:],
      [tc("id", ["dis":"display"]), tc("price", ["dis":"Price", "unit":"\$"])],
      [["foo", n(40, "\$")]])

    // verify old RecId syntax with 2.0 fails
    verifyErr(Err#)
    {
      ZincReader(
      Str<|ver:"2.0"
           id "dis",price "Price" unit:"$"
           "foo",40$
           |>.in).readGrid
    }
  }
  */

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyGrid(Str str, Str:Obj? meta, TestCol[] cols, Obj?[][] cells)
  {
    // decode
    grid  := ZincReader(str.in).readGrid
    verifyMeta(grid.meta, meta)
    verifyCols(grid, cols)
    verifyRows(grid, cells)

    // round-trip
    s := StrBuf()
    w := ZincWriter(s.out)
    w.writeGrid(grid)
    newStr := s.toStr

    // round-trip
    grid = ZincReader(newStr.in).readGrid
    verifyMeta(grid.meta, meta)
    verifyCols(grid, cols)
    verifyRows(grid, cells)


    // rewrite as Java source code for Haystack test suite
    if (str.startsWith("ver:\"2.0\"")) writeJava(str, grid)
  }

  Void verifyCols(Grid grid, TestCol[] tcs)
  {
    verifyEq(grid.cols.isRO, true)
    verifyEq(grid.cols.size, tcs.size)
    verifyNull(grid.col("badColNameReally", false))
    verifyErr(UnknownNameErr#) { grid.col("badColNameReally") }
    verifyErr(UnknownNameErr#) { grid.col("badColNameReally", true) }
    tcs.each |tc| { verifyCol(grid.col(tc.val), tc) }
    grid.cols.each |sc, i| { verifyCol(sc, tcs[i]) }
  }

  Void verifyCol(Col sc, TestCol tc)
  {
    verifyEq(sc.name,   tc.val)
    verifyEq(sc.dis,    tc.meta["dis"] ?: tc.val)
    verifyMeta(sc.meta, tc.meta)
  }

  Void verifyRows(Grid grid, Obj?[][] cells)
  {
    n := 0
    verifyEq(grid.size, cells.size)
    grid.each |Row sr|
    {
      tr := cells[n]
      verifySame(grid[n], sr)
      ++n
      verifyEq(tr.size, grid.cols.size)

      // verify iteration with Row.each
      rowEach := Str:Obj?[:]
      rowEachNames := Str:Str[:]
      sr.each |xv, xn| { rowEach[xn] = xv; rowEachNames[xn] = xn  }

      // verify iteration with Grid.cols
      grid.cols.each |col, i|
      {
        tv := tr[i]
        isNaN := tv is Number && tv.toStr == "NaN"

        // value
        if (isNaN)
        {
          verifyEq(sr.val(col).toStr, "NaN")
          verifyEq(sr.get(col.name).toStr, "NaN")
        }
        else if (tv is Grid)
        {
          g := (Grid)sr.val(col)
          verifyGridEq(g, tv)
        }
        else
        {
          verifyEq(sr.val(col), tv)
          verifyEq(sr.get(col.name), tv)
          verifyEq(sr[col.name], tv)
        }

        // dis
        if (tv is Grid)
        {
          verifyEq(sr.dis(col.name), "<<Nested Grid>>")
        }
        else if (tv != null)
        {
          kind := Kind.fromType(tv.typeof, false)
          if (kind != null)
            verifyEq(sr.dis(col.name), kind.valToDis(tv))
          else
            verifyEq(sr.dis(col.name), tv.toStr)
        }
        else
        {
          verifyEq(sr.dis(col.name), "")
          verifyEq(sr.dis(col.name, "?!"), "?!")
          verifyEq(sr.dis(col.name, null), null)
        }
        verifyEq(sr.dis("badBad"), "")
        verifyEq(sr.dis("badBad", "na"), "na")
        verifyEq(sr.dis("badBad", null), null)
        verifyNotNull(rowEachNames[col.name])

        // has/missing
        if (tv != null)
        {
          verifyEq(sr.has(col.name), true)
          verifyEq(sr.missing(col.name), false)
          if (!isNaN && tv isnot Grid) verifyEq(sr.trap(col.name, null), tv)
        }
        else
        {
          verifyEq(sr.has(col.name), false)
          verifyEq(sr.missing(col.name), true)
          verifyErr(UnknownNameErr#) { sr.trap(col.name, null) }
        }
      }

      // Row get/has/missing/trap with known bad name
      verifyEq(sr["notFound"], null)
      verifyEq(sr.has("notFound"), false)
      verifyEq(sr.missing("notFound"), true)
      verifyErr(UnknownNameErr#) { sr->notFound }
    }
    verifyEq(cells.size, n)
  }

  Void verifyMeta(Dict meta, Str:Obj? map)
  {
    verifyEq(meta.isEmpty, map.isEmpty)
    meta.each |v, k| { verifyEq(map[k], v) }
  }

  TestCol tc(Obj? v, Str:Obj? m := Str:Obj?[:])
  {
    if (v is Int)   v = n(v)
    if (v is Float) v = n(v)
    return TestCol { val = v; meta = m }
  }

//////////////////////////////////////////////////////////////////////////
// Refs
//////////////////////////////////////////////////////////////////////////

 Void testRefs()
 {
   s := Str<|ver:"3.0" siteRef:@17eb894a-26bb44ff "HQ" mark
             id,ref childRef:@17eb894a-26bb44dd "Child" parentRef:@17eb894a-26bb44ee "Parent"
             @17eb894a-26bb4400,@17eb894a-26bb440a
             @17eb894a-26bb4401 "Alpha",@17eb894a-26bb440b "Beta"
             |>
   g := ZincReader(s.in).readGrid
   verifyRef(g.meta, "siteRef", "17eb894a-26bb44ff", "HQ")
   verifyEq(g.meta->mark, Marker.val)
   verifyRef(g.col("ref").meta, "parentRef", "17eb894a-26bb44ee", "Parent")
   verifyRef(g.col("ref").meta, "childRef", "17eb894a-26bb44dd", "Child")
   verifyRef(g[0], "id",  "17eb894a-26bb4400", null)
   verifyRef(g[0], "ref", "17eb894a-26bb440a", null)
   verifyRef(g[1], "id",  "17eb894a-26bb4401", "Alpha")
   verifyRef(g[1], "ref", "17eb894a-26bb440b", "Beta")

   // round trip
   w := ZincWriter.gridToStr(g)
   verifyEq(s.trim, w.trim)
   g = ZincReader(s.in).readGrid
   verifyRef(g.meta, "siteRef", "17eb894a-26bb44ff", "HQ")
   verifyRef(g.col("ref").meta, "parentRef", "17eb894a-26bb44ee", "Parent")
   verifyRef(g.col("ref").meta, "childRef", "17eb894a-26bb44dd", "Child")
   verifyRef(g[1], "id",  "17eb894a-26bb4401", "Alpha")
 }

 Void verifyRef(Dict row, Str tag, Str id, Str? dis)
 {
   Ref ref := row[tag]
   // echo("==> $ref.id $ref.dis ?= $id $dis")
   if (row is Row) verifyEq(((Row)row).dis(tag), dis ?: id)
   verifyEq(ref.id, id)
   verifyEq(ref.disVal, dis)
 }

//////////////////////////////////////////////////////////////////////////
// Tags
//////////////////////////////////////////////////////////////////////////

  Void testTags()
  {
    verifyTags("", Str:Obj[:])
    verifyTags("foo", Str:Obj["foo":Marker.val])
    verifyTags("age:12", Str:Obj["age":n(12)])
    verifyTags("age:12yr", Str:Obj["age":n(12, "yr")])
    verifyTags("name:\"b\" bday:1972-06-07", Str:Obj["name":"b", "bday":Date(1972, Month.jun, 7)])
    verifyTags("name:\"b\" bday:1972-06-07 cool", Str:Obj["name":"b", "bday":Date(1972, Month.jun, 7), "cool":Marker.val])
    verifyTags("foo: 1, bar: 2 baz: 3", ["foo":n(1), "bar":n(2), "baz":n(3)])  // commas
    verifyTags("foo: 1, bar: 2, baz: 3", ["foo":n(1), "bar":n(2), "baz":n(3)])  // commas
  }

  Void verifyTags(Str s, Str:Obj expected)
  {
    actual := ZincReader(s.in).readTags
    verifyDictEq(actual, expected)

    actual = ZincReader(ZincWriter.tagsToStr(expected).in).readTags
    verifyDictEq(actual, expected)
  }

//////////////////////////////////////////////////////////////////////////
// Java
//////////////////////////////////////////////////////////////////////////

  **
  ** Used to generate test code for Haystack Java toolkit
  **
  Void writeJava(Str str, Grid grid) {}

  /*
  {
    out := `foo.txt`.toFile.out(true)

    // opening
    out.printLine
    out.printLine("    verifyGrid(")

    // string literal
    lines := str.splitLines
    str.splitLines.each |line, i|
    {
      out.print("      ").print(toJavaStr(line)[0..-2])
      if  (i < lines.size - 1) out.print("\\n\" + ")
      else out.print("\\n\",")
      out.printLine
    }

    // grid meta
    out.print("      ");
    writeJavaMeta(out, grid.meta).printLine(",")

    // cols
    out.printLine("      new Object[] {");
    grid.cols.each |col|
    {
      out.print("         $col.name.toCode, ");
      writeJavaMeta(out, col.meta)
      out.printLine(",")
    }
    out.printLine("      },");

    // rows
    out.printLine("      new HVal[][] {");
    grid.each |row|
    {
      out.print("        new HVal[] {");
      grid.cols.each |col|
      {
        out.print(toJavaVal(row.get(col.name))).print(", ")
      }
      out.printLine("},");
    }
    out.printLine("      }");

    // closing
    out.printLine("    );")
    out.close
  }

  OutStream writeJavaMeta(OutStream out, Dict tags)
  {
    if (tags.isEmpty) return out.print("null");
    out.print("new HDictBuilder()")
    tags.each |v, n|
    {
      out.print(".add($n.toCode, ${toJavaVal(v)})")
    }
    return out.print(".toDict()")
  }

  Str toJavaVal(Obj? v)
  {
    if (v == null)   return "null"
    if (v is Marker) { return "HMarker.VAL"; }
    if (v is Remove) { return "HStr.make(\"_remove_\")"; }
    if (v is Bool)   { return v == true ? "HBool.TRUE" : "HBool.FALSE";  }
    if (v is Str)    { x := (Str)v; return "HStr.make(${toJavaStr(x)})"; }
    if (v is Ref)    { x := (Ref)v; return "HRef.make(${toJavaStr(x.id)}, ${toJavaStr(x.disVal)})"; }
    if (v is Uri)    { x := (Uri)v; return "HUri.make(${toJavaStr(x.toStr)})"; }
    if (v is Date)   { x := (Date)v; return "HDate.make($x.year, ${x.month.ordinal+1}, $x.day)"; }
    if (v is Time)   { x := (Time)v; ms := x.nanoSec/1_000_000; return "HTime.make($x.hour, $x.min, $x.sec, $ms)"; }
    if (v is Bin)    { x := (Bin)v; return "HBin.make($x.mime.toStr.toCode)"; }
    if (v is Coord)  { x := (Coord)v; return "HCoord.make($x.lat, $x.lng)"; }
    if (v is Number)
    {
      x := (Number)v;
      if (x.isNaN) return "HNum.NaN";
      if (x.toFloat == Float.posInf) return "HNum.POS_INF";
      if (x.toFloat == Float.negInf) return "HNum.NEG_INF";
      s := x.toFloat.toStr
      if (x.unit == null) return "HNum.make($s)";
      return "HNum.make($s, ${toJavaStr(x.unit.toStr)})";
    }
    if (v is DateTime)
    {
      x := (DateTime)v;
      return "HDateTime.make(" + toJavaVal(x.date) + "," + toJavaVal(x.time) + ",HTimeZone.make(" + toJavaStr(x.tz.name) + "))";
    }
    throw Err("$v $v.typeof")
  }

  Str toJavaStr(Str? s)
  {
    if (s == null) return "null"
    return s.toCode('"', true).replace(Str<|\$|>, Str<|$|>)
  }
  */
}

@Js @NoDoc
class TestCol
{
  override Str toStr() { "$val $meta" }
  Obj? val
  [Str:Obj?]? meta
}