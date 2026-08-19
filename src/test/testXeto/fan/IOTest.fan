//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Oct 2023  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** IOTest tests ability to serialize specs/data over Xeto text and binary I/O
**
@Js
class IOTest : AbstractXetoTest
{
  TestClient? client
  TestServer? server

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  Void testBasics()
  {
    ns := createNamespace(["sys", "ph", "hx.test.xeto"])
    server = TestServer(ns)
    client = TestClient(server).boot

    // full fideltity scalars
    verifyIO(null)
    verifyIO(Marker.val)
    verifyIO(NA.val)
    verifyIO(None.val)
    verifyIO("foo")
    verifyIO(n(123))
    verifyIO(n(123, "°F"))
    verifyIO(n(123, "_foo"))
    verifyIO(Number.posInf)
    verifyIO(Number.negInf)
    verifyIO(Number.nan)
    verifyIO(`foo/bar`)
    verifyIO(true)
    verifyIO(Date.today)
    verifyIO(Time.now)
    verifyIO(DateTime.now)
    verifyIO(DateTime("2023-11-17T07:46:32.573-05:00 New_York"))
    verifyIO(Ref("foo"))
    verifyIO(Ref("foo-bar:baz~qux"))
    verifyIO(Ref("foo", "Foo Dis"))
    verifyIO(123)
    verifyIO(-32_000)
    verifyIO(123567890)
    verifyIO(-1235678903)
    verifyIO(123f)
    verifyIO(123min)
    verifyIO(Buf().print("foobar"))
    verifyIO(Version("1.2.3"))
    verifyIO(Etc.dict0)
    verifyIO(Etc.dict1("foo", m))
    verifyIO(Etc.dict2("foo", m, "bar", n(123)))
    verifyIO(Coord(12f, -34f))
    verifyIO(Symbol("foo-bar"))
    verifyIO(Span.today)
    verifyIO(Span(Date("2024-11-21")))

    // loss of fideltity scalars
    verifyIO(Unit("kW"))
    verifyIO(UnitQuantity.volume)
    verifyIO(SpanMode.lastMonth)
    verifyIO(Filter("a and b"))
    verifyIO(LibDependVersions("4.5.x"))
    verifyIO(Scalar("hx.test.xeto::ScalarB", "beta"))

    // lists
    verifyIO(Obj?[,])
    verifyIO(Obj?["a"])
    verifyIO(Obj?["a", n(123)])
    verifyIO(Obj?["a", null, n(123)])

    // dicts
    a := ns.instantiate(ns.spec("ph::AcElecMeter"))
    b := dict(["spec":Ref("ph::Rtu"), "dis":"RTU", "equip":m, "ahu":m, "rtu":m])
    verifyIO(a)
    verifyIO(b)
    verifyIO([a, b])
    verifyIO(["foo", n(123), a, b])

    a = Etc.dictSet(a, "id", Ref.gen)
    b = Etc.dictSet(b, "id", Ref.gen)
    verifyIO(a)
    verifyIO(b)
    verifyIO([a, b])
    verifyIO(["foo", n(123), a, b])

    // typed dict
    c := TestVal.makeNumber(n(45), "ok")
    x := verifyIO(c)
    verifySame(x.typeof, c.typeof)

    // grid
    g := Etc.makeMapsGrid(["meta":"val"], [
        ["dis":"A", "foo":n(123)],
        ["dis":"B", "bar":m]
      ])
    g = g.addColMeta("dis", ["disMeta":m])
    verifyIO(g)

    // grid nested as dict tag value (subject envelope pattern)
    env := dict(["sni":"/db/ph::Equip", "spec":Ref("sys::Collection"), "data":g])
    buf := Buf()
    ns.io.writeBinary(buf.out, env)
    Dict envx := ns.io.readBinary(buf.flip.in)
    verifyEq(envx->sni, "/db/ph::Equip")
    verifyEq(envx->spec, Ref("sys::Collection"))
    verifyGridEq(envx->data, g)
  }

  ** Round trip through clean JSON at box=auto, the lossless box mode.  One
  ** thing clean JSON cannot carry, so it is not asserted: a list's element
  ** type, since a JSON array has nowhere to put it and the reader can only
  ** infer nullability from an actual null.
  Void verifyJsonIO(Obj? val)
  {
    ns := server.ns

    opts := Etc.dict2("box", "auto", "pretty", Marker.val)
    str  := ns.io.writeJetoToStr(val, opts)
    x    := ns.io.readJeto(str.in, ns.specOf(val, false))

    if (val is List)
    {
      List orig := val
      List read := x
      verifyEq(read.size, orig.size)
      orig.each |v, i| { verifyValEq(v, read[i]) }
    }
    else
    {
      verifyValEq(val, x)
    }
  }

  Obj? verifyIO(Obj? val)
  {
    ns := server.ns

    // binary format
    buf := Buf()
    ns.io.writeBinary(buf.out, val)
    // echo("--> $val [$buf.size bytes]")
    binary := ns.io.readBinary(buf.flip.in)
    // echo("  > $binary | ${binary?.typeof}")
    verifyValEq(val, binary)

    // JSON format
    verifyJsonIO(val)

    // Xeto format does not support null
    if (val == null) return binary
    list := val as Obj?[]
    if (list != null)
    {
      if (list.contains(null)) return binary
      if (!list.isEmpty && list.all { it is xeto::Dict })
        val = xeto::Dict[,].addAll(list)
      else
        val = Obj[,].addAll(list)
    }

    // xeto text format
    buf.clear
    ns.io.writeXeto(buf.out, val)
    str := buf.flip.readAllStr
    opts := dict1("externRefs", m)
    x := server.ns.io.readXeto(str, opts)
    verifyValEq(val, x)

    // compileDicts
    if (val is Dict)
    {
      dicts := ns.io.readXetoDicts(str, opts)
      verifyEq(dicts.size, 1)
      verifyDictEq(dicts[0], val)
    }
    else if (val is List && ((List)val).all { it is Dict })
    {
      dicts := ns.io.readXetoDicts(str, opts)
      verifyDictsEq(dicts, val)
    }
    else
    {
      verifyErr(IOErr#) { ns.io.readXetoDicts(str, opts) }
    }
    return binary
  }

//////////////////////////////////////////////////////////////////////////
// Grids
//////////////////////////////////////////////////////////////////////////

  ** The examples from the doc.xeto::Grids chapter must round trip
  Void testGrids()
  {
    ns := createNamespace(["sys", "ph", "hx.test.xeto"])
    server = TestServer(ns)
    client = TestClient(server).boot

    // Shape section example
    src := Str<|Grid {
                  meta: {foo: "quux"}
                  cols: {
                    {name: "a"},
                    {name: "b", meta: {dis: "B"}}
                  }
                  rows: {
                    {a: 0, b: "x"},
                    {a: 1, b: "y"}
                  }
                }|>
    g := (Grid)ns.io.readXeto(src)
    verifyEq(g.meta["foo"], "quux")
    verifyEq(g.cols.size, 2)
    verifyEq(g.col("b").meta["dis"], "B")
    verifyEq(g.size, 2)
    verifyEq(g[0]["a"], "0")  // untyped cell is a Str in xeto
    verifyEq(g[1]["b"], "y")
    verifyIO(g)

    // Cell Types section example: col 'of' decodes the cells
    src = Str<|Grid {
                 cols: {
                   {name: "ts", of: DateTime},
                   {name: "val", of: Number}
                 }
                 rows: {
                   {ts: "2026-01-01T00:00:00Z", val: 72°F},
                   {ts: "2026-01-01T00:15:00Z", val: 73°F}
                 }
               }|>
    g = (Grid)ns.io.readXeto(src)
    verifyEq(g[0]["ts"], DateTime("2026-01-01T00:00:00Z UTC"))
    verifyEq(g[0]["val"], n(72, "°F"))
    verifyEq(g[1]["ts"], DateTime("2026-01-01T00:15:00Z UTC"))
    verifyEq(XetoUtil.gridColSpecRef(g.col("ts")), Ref("sys::DateTime"))
    verifyIO(g)

    // grid 'of' default row spec decodes cells by member
    src = Str<|Grid {
                 of: Site
                 cols: {
                   {name: "dis"},
                   {name: "area"}
                 }
                 rows: {
                   {dis: "A", area: "45"}
                 }
               }|>
    g = (Grid)ns.io.readXeto(src)
    verifyEq(XetoUtil.gridOfSpecRef(g), Ref("ph::Site"))
    verifyEq(g[0]["area"], n(45))
    verifyIO(g)

    // cell typing matrix: a cell or row with its own type keeps it, then
    // the column 'of', then the row spec member, where the row spec is
    // the row's own type else the grid 'of'
    src = Str<|Grid {
                 of: GridRowA
                 cols: { {name: "cell"}, {name: "other", of: Number}, {name: "extra", of: Number} }
                 rows: {
                   {cell: "2026-01-02"},
                   GridRowB {cell: "00:15:00"},
                   {other: "45"},
                   GridRowB {extra: "48"},
                   {cell: Time "00:30:00"},
                   {other: Date "2026-01-03"}
                 }
               }|>
    g = (Grid)ns.io.readXeto(src)
    verifyEq(g[0]["cell"], Date("2026-01-02"))            // grid 'of' member
    verifyEq(g[1]["cell"], Time("00:15:00"))              // row type beats grid 'of'
    verifyEq(g[1]["spec"], null)                          // rows are columnar: the type governs decoding, the tag is not a cell
    verifyEq(g[2]["other"], n(45))                        // col 'of' beats grid 'of' member
    verifyEq(g[3]["extra"], n(48))                        // col 'of' applies within a typed row
    verifyEq(g[4]["cell"], Time("00:30:00"))              // explicit cell type beats the member
    verifyEq(g[5]["other"], Date("2026-01-03"))           // explicit cell type beats col 'of'
    verifyIO(g)

    // a col 'of' contradicting a typed row's declared member is an error
    verifyErrMsg(XetoCompilerErr#, "Slot 'other': Slot type is 'sys::Str', value type is 'sys::Number'")
    {
      ns.io.readXeto(Str<|Grid {
                            cols: { {name: "other", of: Number} }
                            rows: { GridRowB {other: "46"} }
                          }|>)
    }

    // nested dicts, lists, and non-string scalars in grid meta and col meta
    src = Str<|Grid {
                 meta: {count: Number "2", span: {start: Date "2026-01-01", end: Date "2026-01-31"}, tags: List {"a", "b"}}
                 cols: {
                   {name: "a", meta: {when: Date "2026-08-19", limits: List {Number "1", Number "2"}, nest: {deep}}}
                 }
                 rows: { {a: "x"} }
               }|>
    g = (Grid)ns.io.readXeto(src)
    verifyEq(g.meta["count"], n(2))
    verifyEq(((Dict)g.meta["span"])["end"], Date("2026-01-31"))
    verifyEq(((List)g.meta["tags"])[1], "b")
    cm := g.col("a").meta
    verifyEq(cm["when"], Date("2026-08-19"))
    verifyEq(((List)cm["limits"])[0], n(1))
    verifyEq(((Dict)cm["nest"])["deep"], m)

    // round trip the text; nested dict values compare per tag since
    // Dict equality is identity
    rt := (Grid)ns.io.readXeto(ns.io.writeXetoToStr(g))
    verifyEq(rt.meta["count"], n(2))
    verifyEq(((Dict)rt.meta["span"])["start"], Date("2026-01-01"))
    verifyEq(((List)rt.meta["tags"])[1], "b")
    verifyEq(((List)rt.col("a").meta["limits"])[1], n(2))
    verifyEq(((Dict)rt.col("a").meta["nest"])["deep"], m)

    // nested dicts, lists, refs, markers, typed scalars, and grids as cells
    src = Str<|Grid {
                 meta: {when: Date "2026-08-19"}
                 cols: { {name: "a"}, {name: "b"} }
                 rows: {
                   {a: {x: Date "2026-08-19", nest: {y: 1}}, b: List {"s", 2}},
                   {a: @ext-ref, b},
                   {a: Coord "C(37.55,-77.45)", b: Grid { cols: { {name: "n"} }, rows: { {n: "inner"} } }}
                 }
               }|>
    g = (Grid)ns.io.readXeto(src, dict1("externRefs", m))
    verifyEq(g.meta["when"], Date("2026-08-19"))
    a0 := (Dict)g[0]["a"]
    verifyEq(a0["x"], Date("2026-08-19"))
    verifyEq(((Dict)a0["nest"])["y"], "1")  // untyped scalar is a Str
    verifyEq(((List)g[0]["b"])[0], "s")
    verifyEq(((List)g[0]["b"])[1], "2")
    verifyEq(g[1]["a"], Ref("ext-ref"))
    verifyEq(g[1]["b"], m)
    verifyEq(g[2]["a"], Coord(37.55f, -77.45f))
    inner := (Grid)g[2]["b"]
    verifyEq(inner.first["n"], "inner")

    // xeto text round trip only: json cannot carry the list cell's
    // element type, the same limit verifyJsonIO documents
    verifyGridEq((Grid)ns.io.readXeto(ns.io.writeXetoToStr(g), dict1("externRefs", m)), g)

    // grid shaped dict nested in an ordinary dict converts too
    x := (Dict)ns.io.readXeto(
      Str<|{history: Grid { cols: { {name: "a"} }, rows: { {a: "1"} } }}|>)
    verify(x["history"] is Grid)
    verifyEq(((Grid)x["history"]).first["a"], "1")

    // grid constant in a lib is a slot value, like List
    inst := ns.lib("hx.test.xeto").instance("test-grid")
    g = (Grid)inst["grid"]
    verifyEq(g.meta["foo"], "bar")
    verifyEq(g[0]["area"], n(10))
    verifyEq(g[1]["dis"], "B")
    verifyIO(g)

    // a grid is a value, never a named instance - in libs and data files
    gridInst := Str<|@g: Grid { cols: { {name: "a"} }, rows: { {a: "1"} } }|>
    verifyErrMsg(XetoCompilerErr#, "Grid cannot be a named instance") { ns.compileTempLib(gridInst) }
    verifyErrMsg(XetoCompilerErr#, "Grid cannot be a named instance") { ns.io.readXeto(gridInst) }
  }

//////////////////////////////////////////////////////////////////////////
// This
//////////////////////////////////////////////////////////////////////////

  Void testRefNoDis()
  {
    // ref with dis when encodeRefDis is true (default)
    ref := Ref("foo", "Foo Dis")
    buf := Buf()
    w := XetoBinaryWriter(buf.out)
    w.writeVal(ref)
    r := XetoBinaryReader(buf.flip.in)
    x := r.readVal as Ref
    verifyEq(x.id, "foo")
    verifyEq(x.disVal, "Foo Dis")

    // ref with dis when encodeRefDis is false
    buf.clear
    w = XetoBinaryWriter(buf.out)
    w.encodeRefDis = false
    w.writeVal(ref)
    r = XetoBinaryReader(buf.flip.in)
    x = r.readVal as Ref
    verifyEq(x.id, "foo")
    verifyEq(x.disVal, null)

    // ref without dis always encodes the same
    refNoDis := Ref("bar")
    buf.clear
    w = XetoBinaryWriter(buf.out)
    w.writeVal(refNoDis)
    size1 := buf.size
    buf.clear
    w = XetoBinaryWriter(buf.out)
    w.encodeRefDis = false
    w.writeVal(refNoDis)
    verifyEq(buf.size, size1)
  }

  Void testThis()
  {
    ns := createNamespace(["hx.test.xeto"])

    spec := ns.spec("hx.test.xeto::InstantiateD")
    expect := ["spec":spec.id, "numA":n(2026), "numB":n(37)]

    verifyThis(ns, ns.spec("sys::Number"), n(123),
      Str<|This "123"|>)

    verifyThis(ns, spec, expect,
      Str<|This {
             numA: "2026"
           }|>)

   verifyThis(ns, spec, expect,
     Str<|sys::This {
            numA: "2026"
          }|>)

    verifyThis(ns, spec, expect.add("id", Ref("foo")),
      Str<|@foo: This {
            numA: "2026"
           }|>)
   }

  Void verifyThis(Namespace ns, Spec spec, Obj expect, Str xeto)
  {
    // verify failures if this not injected
    verifyErrMsg(XetoCompilerErr#, "Must set 'this' in opts") {ns.io.readXeto(xeto) }

    // verify This infers injected type for its slots
    x := ns.io.readXeto(xeto, Etc.dict1("this", spec))
    if (expect is Map)
      verifyDictEq(x, expect)
    else
      verifyValEq(x, expect)
  }

}

