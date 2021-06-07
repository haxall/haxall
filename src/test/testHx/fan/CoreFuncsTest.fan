//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using concurrent
using haystack
using axon
using folio
using hx

**
** CoreFuncsTest
**
class CoreFuncsTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Folio
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFolio()
  {
    // create test database
    a := makeRec("andy",    10, ["young"])
    b := makeRec("brian",   20, ["young"])
    c := makeRec("charlie", 30, ["old"])
    d := makeRec("dan",     30, ["old", "smart"])
    k := addRec(["return":Marker.val, "do": "end"])
    badId := Ref.gen

    // create test funcs
    five     := addFuncRec("five", "()=>5")
    addem    := addFuncRec("addem", "(a, b) => do x: a; y: b; x + y; end")
    findFive := addFuncRec("findFive", "() => core::readByName(\"five\")")
    findDan  := addFuncRec("findDan",  "() => core::read(smart)")
    allOld   := addFuncRec("allOld",   "() => core::readAll(old)")

    // readById
    verifyEval("readById($c.id.toCode)", c)
    verifyEval("readById($badId.toCode, false)", null)
    verifyEvalErr("readById($badId.toCode)", UnknownRecErr#)
    verifyEvalErr("readById($badId.toCode, true)", UnknownRecErr#)

    // readById
    verifyEval("readByIds([]).isEmpty", true)
    verifyEval("readByIds([$a.id.toCode])", toGrid([a]))
    verifyEval("readByIds([$a.id.toCode, $b.id.toCode])", toGrid([a, b]))
    verifyEval("readByIds([$a.id.toCode, $b.id.toCode, $d.id.toCode])", toGrid([a, b, d]))
    verifyDictEq(eval("readByIds([$a.id.toCode, $b.id.toCode, $d.id.toCode])")->get(0), a)
    verifyDictEq(eval("readByIds([$a.id.toCode, $b.id.toCode, $d.id.toCode])")->get(1), b)
    verifyDictEq(eval("readByIds([$a.id.toCode, $b.id.toCode, $d.id.toCode])")->get(2), d)
    verifyDictEq(eval("readByIds([$a.id.toCode, @badId], false)")->get(0), a)
    verifyDictEq(eval("readByIds([$a.id.toCode, @badId], false)")->get(1), Etc.emptyDict)

    // trap on id
    verifyEq(eval("(${a.id.toCode})->n"), "andy")
    verifyEq(eval("readById($a.id.toCode)->age"), n(10))

    // read
    verifyEval("read(smart)", d)
    verifyEval("do f: \"smart\".parseFilter; read(f); end", d)
    verifyEval("read(\"smart\".parseFilter)", d)
    verifyEval("read(parseFilter(\"smart\"))", d)
    verifyEval("parseFilter(\"smart\").read", d)
    verifyEval("read(fooBar, false)", null)
    verifyEvalErr("read(fooBar)", UnknownRecErr#)
    verifyEvalErr("read(fooBar, true)", UnknownRecErr#)
    verifyEval(Str<|read("else", false)|>, null)
    verifyEval(Str<|read("return", false)|>, k)
    verifyEval(Str<|read("return" or "else")|>, k)
    verifyEval(Str<|read("return" and "else", false)|>, null)

    // readAll
    verifyReadAll("young",     [a, b])
    verifyReadAll("age == 30", [c, d])
    verifyReadAll("age == 30", [c, d])
    verifyReadAll("age != 30", [a, b])
    verifyReadAll("age < 20",  [a])
    verifyReadAll("age <= 20", [a, b])
    verifyReadAll("age > 20",  [c, d])
    verifyReadAll("age >= 20", [b, c, d])
    verifyReadAll("age == 10 or age == 30", [a, c, d])
    verifyReadAll("age == 30 and smart", [d])
    verifyEval(Str<|readAll("else" or "return")|>, toGrid([k]))
    verifyEval(Str<|readAll(("else" or "return"))|>, toGrid([k]))
    verifyEval(Str<|readAll("else" and "return").size|>, n(0))
    verifyEval(Str<|readAll("do" == "end")|>, toGrid([k]))
    verifyEval(Str<|readAll(("else" and "return") or "do")|>, toGrid([k]))

    // get all tags/vals
    verifyGridList("readAllTagNames(def).keepCols([\"name\"])", "name", ["def", "id", "mod", "src"])
    verifyGridList("readAllTagVals(age < 20, \"id\")", "val", [a.id])

    dict := (Dict)eval("readLink($d.id.toCode)")
    verifyEq(Etc.dictNames(dict), ["id", "age", "n", "old", "smart", "mod"])

    // rec functions
    /* TODO
    verifyEval("five()", n(5))
    verifyEval("addem(3, 6)", n(9))
    verifyEval("addem(3, 6)", n(9))
    verifyEval("findFive()", rt.db.read("name==\"five\""))
    verifyEval("findDan()", d)
    verifyEval("allOld()", [c, d])
    */
  }

  Dict makeRec(Str name, Int age, Str[] markers)
  {
    tags := Str:Obj?["n":name, "age":n(age)]
    markers.each |marker| { tags.add(marker, Marker.val) }
    return addRec(tags)
  }

  Dict addFuncRec(Str name, Str src, Str:Obj? tags := Str:Obj?[:])
  {
    tags["def"] = "func:$name"
    tags["src"]  = src
    r := addRec(tags)
    return r
  }

  Void verifyReadAll(Str filter, Dict[] expected)
  {
    verifyDictsEq(eval("readAll($filter)")->toRows, expected, false)
    verifyDictsEq(eval("readAll(${filter.toCode}.parseFilter)")->toRows, expected, false)
    verifyEval("readCount($filter)", n(expected.size))
  }

  Void verifyGridList(Str expr, Str colName, Obj[] vals)
  {
    Grid grid := eval(expr)
    verifyEq(grid.cols.size, 1)
    verifyEq(grid.cols[0].name, colName)
    verifyEq(grid.size, vals.size)
    vals.each |val, i| { verifyEq(val, grid[i][colName]) }
  }

//////////////////////////////////////////////////////////////////////////
// Coercions (toRec, toRecId, etc)
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testCoercion()
  {
    d1 := Etc.makeDict1("id", Ref("d1"))
    d2 := Etc.makeDict1("id", Ref("d2"))
    g1 := Etc.makeDictGrid(null, d1)

    verifyToId(null,        null)
    verifyToId(Ref("null"), Ref.nullRef)
    verifyToId(Ref("a"),    Ref("a"))
    verifyToId(d1,          Ref("d1"))
    verifyToId(g1,          Ref("d1"))

    verifyToIds(null,                 null)
    verifyToIds(Ref("null"),          Ref[Ref.nullRef])
    verifyToIds(Ref("a"),             Ref[Ref("a")])
    verifyToIds([Ref("a"), Ref("b")], Ref?[Ref("a"), Ref("b")])
    verifyToIds(d1,                   Ref[Ref("d1")])
    verifyToIds([d1],                 Ref[Ref("d1")])
    verifyToIds([d1, d2],             Ref[Ref("d1"), Ref("d2")])
  }

  Void verifyToId(Obj? val, Obj? expected)
  {
    cx := makeContext
    if (expected != null)
    {
      actual := HxUtil.toId(val)
      verifyEq(actual, expected)
      verifyEq(HxUtil.toIds(val), Ref[expected])
      verifyEq(cx.evalToFunc("toRecId").call(cx, [val]), expected)
      verifyEq(cx.evalToFunc("toRecIdList").call(cx, [val]), Ref[expected])
    }
    else
    {
      verifyErr(Err#) { HxUtil.toId(val) }
      verifyErr(Err#) { HxUtil.toIds(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toRecId").call(cx, [val]) }
      verifyErr(EvalErr#) { cx.evalToFunc("toRecIds").call(cx, [val]) }
    }
  }

  Void verifyToIds(Obj? val, Ref[]? expected)
  {
    cx := makeContext
    if (expected != null)
    {
      actual := HxUtil.toIds(val)
      verifyEq(actual, expected)
      verifyEq(HxUtil.toIds(val), expected)
      verifyEq(cx.evalToFunc("toRecIdList").call(cx, [val]), expected)
    }
    else
    {
      verifyErr(Err#) { HxUtil.toIds(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toRecIds").call(cx, [val]) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Diff
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testDiff()
  {
    db := rt.db

    // diff only - add
    Diff? d
    verifyEvalErr("""diff(null, {dis:"test", age:33})""", ArgErr#)
    verifyEvalErr("""diff({}, {dis:"test", age:33}, {add})""", ArgErr#)
    d = eval("""diff(null, {dis:"test", age:33}, {add})""")
    verifyDictEq(d.changes, ["dis":"test", "age":n(33)])
    verifyEq(d.flags, Diff.add)

    // diff only - remove tag
    d = eval("""diff({id:@14754350-63a873e5, mod:now()}, {-age}, {transient, force})""")
    verifyDictEq(d.changes, ["age":Remove.val])
    verifyEq(d.flags, Diff.transient.or(Diff.force))

    // diff only - add with explicit id
    d = eval("""diff(null, {id:@14754350-63a873ff, dis:"makeAdd"}, {add})""")
    verifyDiffEq(d, Diff.makeAdd(["dis":"makeAdd"], Ref("14754350-63a873ff")))

    // commit+diff - add
    eval("""commit(diff(null, {dis:"diff-a", foo, i:123}, {add}))""")
    r := db.read(Str<|dis=="diff-a"|>)
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"diff-a", "foo":Marker.val, "i":n(123)])

    // commit+diff - change with tag remove, tag add, tag update
    eval("""commit(diff(readById($r.id.toCode), {-foo, i:456, s:"!"}))""")
    r = db.read(Str<|dis=="diff-a"|>)
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"diff-a", "i":n(456), "s":"!"])

    // commit+diff - makeAdd with explicit id
    xId := Ref.gen
    eval("""commit(diff(null, {id:$xId.toCode, dis:"diff-b"}, {add}))""")
    r = db.read(Str<|dis=="diff-b"|>)
    verifyDictEq(r, ["id":Ref(r.id.id, "diff-b"), "mod":r->mod, "dis":"diff-b"])

    // commit with sparse cols in grid
    eval("""[{dis:"g1", a:10}, {dis:"g2", b:20}].toGrid
            .each x => commit(diff(null, x, {add}))""")
    r = db.read(Str<|dis=="g1"|>)
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"g1", "a":n(10)])
    r = db.read(Str<|dis=="g2"|>)
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"g2", "b":n(20)])
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testCommit()
  {
    db := rt.db

    Dict a := eval("""commit(diff(null, {dis:"A", foo, count:10}, {add}))""")
    verifyDictEq(db.readById(a.id), ["dis":"A", "foo":m, "count":n(10), "id":a.id, "mod":a->mod])

    Dict b := eval("""commit(diff(null, {dis:"B", count:12}, {add}))""")
    verifyDictEq(db.readById(b.id), ["dis":"B", "count":n(12), "id":b.id,  "mod":b->mod])

    Dict[] x := eval(
      """[diff(read(dis=="A"), {count:3, -foo}),
          diff(read(dis=="B"), {count:4, bar})].commit""")
    verifyEq(x.size, 2)
    verifyDictEq(x[0], ["dis":"A", "count":n(3), "id":a.id, "mod":x[0]->mod])
    verifyDictEq(x[1], ["dis":"B", "count":n(4), "bar":m, "id":b.id, "mod":x[1]->mod])

  }

//////////////////////////////////////////////////////////////////////////
// Strip Uncommittable
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testStripUncommittable()
  {
    db := rt.db

    r := addRec(["dis":"Test", "foo":m])
    db.commit(Diff(r, ["bar":"what"], Diff.transient))

    verifyDictEq(eval("stripUncommittable({foo, hisSize, curVal})"), ["foo":m])
    verifyDictEq(eval("stripUncommittable({id:@bad, connErr, point})"), ["id":Ref("bad"), "point":m])
    verifyDictEq(eval("stripUncommittable({id:@bad, connErr, point, bad:null})"), ["id":Ref("bad"), "point":m])
    verifyDictEq(eval("readById($r.id.toCode).stripUncommittable"), ["id":r.id, "dis":"Test", "foo":m])

    x := (Dict[])eval("readAll(foo).stripUncommittable")
    verifyDictEq(x[0], ["id":r.id, "dis":"Test", "foo":m])

    x = eval("readAllStream(foo).collect(toList).stripUncommittable")
    verifyDictEq(x[0], ["id":r.id, "dis":"Test", "foo":m])

    verifyDictEq(eval("stripUncommittable({id:@a, hisSize:123, foo, mod:now()})"),
      ["id":Ref("a"), "foo":m])

    verifyDictEq(eval("stripUncommittable({id:@a, hisSize:123, foo, mod:now()}, {-id})"),
      ["foo":m])
  }

//////////////////////////////////////////////////////////////////////////
// Streams
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testStreams()
  {
    db := rt.db

    // create test database
    a := addRec(["dis":"andy",    "age":n(10), "young":m])
    b := addRec(["dis":"brian",   "age":n(20), "young":m])
    c := addRec(["dis":"charlie", "age":n(30), "old":m])
    d := addRec(["dis":"dan",     "age":n(30), "old":m, "smart":m])
    badId := Ref.gen

    // readAllStream
    verifyStream("readAllStream(age).collect", [a, b, c, d])
    verifyStream("readAllStream(age <= 20).collect", [a, b])
    verifyStream("readAllStream(age).limit(3).collect", db.readAllList("age")[0..2])

    // readByIdsStream
    verifyStream("readByIdsStream([$a.id.toCode, $c.id.toCode, $b.id.toCode]).collect", [a, c, b])
    verifyStream("readByIdsStream([$a.id.toCode, $c.id.toCode, $b.id.toCode]).limit(2).collect", [a, c])

    // commit
    verifyEq(eval("""(1..5).stream.map(n=>diff(null, {dis:"C-"+n, commitTest}, {add})).commit"""), n(5))
    g := db.readAll("commitTest").sortCol("dis")
    verifyEq(g.size, 5)
    verifyEq(g[0].dis, "C-1")
    verifyEq(g[4].dis, "C-5")
  }

  Obj? verifyStream(Str src, Obj? expected)
  {
    // verify normally
    actual := eval(src)
    verifyStreamEq(actual, expected)

    // verify roundtrip encoded/decoded
    actual = roundTripStream(makeContext, src)
    verifyStreamEq(actual, expected)
    return actual
  }

  private Void verifyStreamEq(Obj? actual, Obj? expected)
  {
    if (expected is Dict[])
      verifyDictsEq(actual, expected, false)
    else
      verifyValEq(actual, expected)
  }

  ** Encode stream, decode it, and then re-evaluate it.
  ** The terminal expr cannot have a dot
  static Obj? roundTripStream(AxonContext cx, Str src)
  {
    Slot.findMethod("testAxon::StreamTest.roundTripStream").callOn(null, [cx, src])
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testMisc()
  {
    cx := makeContext
    verifyEq(cx.user.isSu, true)
    verifyEq(cx.user.isAdmin, true)

    d := (Dict)cx.eval("about()")
    verifyEq(d->productName, rt.config->productName)
    verifyEq(d->productUri, rt.config->productUri)
    verifyEq(d->productVersion, rt.config->productVersion)

    d = (Dict)cx.eval("context()")
    verifyEq(d->userRef, cx.user.id)
    verifyEq(d->username, cx.user.username)
    verifyEq(d->locale, Locale.cur.toStr)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Obj? verifyEval(Str src, Obj? expected)
  {
    actual := eval(src)
    // echo; echo("-- $src"); echo(actual)
    verifyValEq(actual, expected)
    return actual
  }

  Obj? eval(Str src)
  {
    makeContext.eval(src)
  }

  Void verifyEvalErr(Str axon, Type? errType)
  {
    expr := Parser(Loc.eval, axon.in).parse
    cx := makeContext
    EvalErr? err := null
    try { expr.eval(cx) } catch (EvalErr e) { err = e }
    if (err == null) fail("EvalErr not thrown: $axon")
    if (errType == null)
    {
      verifyNull(err.cause)
    }
    else
    {
      if (err.cause == null) fail("EvalErr.cause is null: $axon")
      ((Test)this).verifyErr(errType) { throw err.cause }
    }
  }

  Void verifyDiffEq(Diff a, Diff b)
  {
    a.typeof.fields.each |f|
    {
      if (f.isStatic) return
      av := f.get(a)
      bv := f.get(b)
      if (av is Dict) verifyDictEq(av, bv)
      else verifyEq(av, bv)
    }
  }

  static Grid toGrid(Dict[] recs) { Etc.makeDictsGrid(null, recs) }

  static Dict d(Obj x) { Etc.makeDict(x) }

}