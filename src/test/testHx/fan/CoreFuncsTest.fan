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
// Context
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testContext()
  {
    cx := makeContext
    d := (Dict)cx.eval("context()")
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

  static Grid toGrid(Dict[] recs) { Etc.makeDictsGrid(null, recs) }

  static Dict d(Obj x) { Etc.makeDict(x) }

}