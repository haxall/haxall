//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Jun 2021  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using axon
using folio
using hx

**
** HxFuncsTest
**
class HxFuncsTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Folio
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testFolio()
  {
    // create test databaseb
    a := makeRec("andy",    10, ["young"])
    b := makeRec("brian",   20, ["young"])
    c := makeRec("charlie", 30, ["old"])
    d := makeRec("dan",     30, ["old", "smart"])
    k := addRec(["return":Marker.val, "do": "end"])
    badId := Ref.gen

    // create test funcs
    five     := addFunc("five", "()=>5")
    addem    := addFunc("addem", "(a, b) => do x: a; y: b; x + y; end")
    findFive := addFunc("findFive", "() => func(five)")
    findDan  := addFunc("findDan",  "() => read(smart)")
    allOld   := addFunc("allOld",   "() => readAll(old).sort(\"dis\")")

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
    verifyDictEq(eval("readByIds([$a.id.toCode, @badId], false)")->get(1), Etc.dict0)

    // trap on id
    verifyEq(eval("(${a.id.toCode})->dis"), "andy")
    verifyEq(eval("readById($a.id.toCode)->age"), n(10))

    // read
    verifyEval("read(smart)", d)
    verifyEval("do f: \"smart\".parseFilter; read(f); end", d)
    verifyEval("do f: \"ndy\".parseSearch; read(f); end", a)
    verifyEval("read(\"smart\".parseFilter)", d)
    verifyEval("read(\"bri\".parseSearch)", b)
    verifyEval("read(parseFilter(\"smart\"))", d)
    verifyEval("read(parseSearch(\"charlie\"))", c)
    verifyEval("parseFilter(\"smart\").read", d)
    verifyEval("parseSearch(\"charlie\").read", c)
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
    verifyGridList("readAllTagNames(age).keepCols([\"name\"])", "name", ["age", "dis", "id", "mod", "old", "smart", "young"])
    verifyGridList("readAllTagVals(age < 20, \"id\")", "val", [a.id])

    dict := (Dict)eval("readLink($d.id.toCode)")
    verifyEq(Etc.dictNames(dict), ["id", "age", "dis", "old", "smart", "mod"])

    // rec functions
    verifyEval("five()", n(5))
    verifyEval("addem(3, 6)", n(9))
    verifyEval("addem(3, 6)", n(9))
    verifyEval("findFive()->qname", "proj::five")
    verifyEval("findDan()", d)
    verifyEval("allOld()", toGrid([c, d]))
  }

  Dict makeRec(Str name, Int age, Str[] markers)
  {
    tags := Str:Obj?["dis":name, "age":n(age)]
    markers.each |marker| { tags.add(marker, Marker.val) }
    return addRec(tags)
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

  @HxTestProj
  Void testCoercion()
  {
    addLib("hx.test.xeto")
    d1 := Etc.dict1("id", Ref("d1"))
    d2 := Etc.dict1("id", Ref("d2"))
    g0 := Etc.emptyGrid
    g1 := Etc.makeDictGrid(null, d1)
    r  := addRec(["dis":"rec in db"])
    s  := proj.ns.spec("hx.test.xeto::TestSite")
    i  := proj.ns.instance("hx.test.xeto::test-a")

    // Etc.toId, toRecId
    verifyToId(null,        null)
    verifyToId(Ref[,],      null)
    verifyToId(g0,          null)
    verifyToId(Ref("null"), Ref.nullRef)
    verifyToId(Ref("a"),    Ref("a"))
    verifyToId(d1,          Ref("d1"))
    verifyToId(g1,          Ref("d1"))
    verifyToId(s,           s.id)
    verifyToId(i,           i.id)

    // Etc.toIds, toRecIdList
    verifyToIds(null,                 null)
    verifyToIds(Ref("null"),          Ref[Ref.nullRef])
    verifyToIds(Ref("a"),             Ref[Ref("a")])
    verifyToIds([Ref("a"), Ref("b")], Ref?[Ref("a"), Ref("b")])
    verifyToIds(d1,                   Ref[Ref("d1")])
    verifyToIds([d1],                 Ref[Ref("d1")])
    verifyToIds([d1, d2],             Ref[Ref("d1"), Ref("d2")])
    verifyToIds([,],                  Ref[,])
    verifyToIds(g0,                   Ref[,])
    verifyToIds([s],                  Ref[s.id])
    verifyToIds([i],                  Ref[i.id])

    // Etc.toRec, toRec
    verifyToRec(null,    null)
    verifyToRec(this,    null)
    verifyToRec(Ref[,],  null)
    verifyToRec(Dict[,], null)
    verifyToRec(d1.id,   null)
    verifyToRec(d1,      d1)
    verifyToRec(r.id,    r)
    verifyToRec(r,       r)
    verifyToRec([d1.id], null)
    verifyToRec([r.id],  r)
    verifyToRec([d1],    d1)
    verifyToRec([r],     r)
    verifyToRec(Etc.makeDictGrid(null, d1), d1)
    verifyToRec(s, s, true)
    verifyToRec(i, i, true)
    verifyToRec(s.id, s, true)
    verifyToRec(i.id, i, true)

    // Etc.toRecs, toRecList
    verifyToRecs(this,     null)
    verifyToRecs(null,     Dict[,])
    verifyToRecs(d1,       [d1])
    verifyToRecs([d1],     [d1])
    verifyToRecs([d1, d2], [d1, d2])
    verifyToRecs(d1.id,    null)
    verifyToRecs([d1.id],  null)
    verifyToRecs(r.id,     [r])
    verifyToRecs([r.id],   [r])
    verifyToRecs([r.id, d1.id],  null)
    verifyToRecs(Etc.makeDictsGrid(null, [r, d1]),  [r, d1])
    verifyToRecs([s.id, i.id],  [s, i])

    // Etc.toDateSpan (each one also is tested as toSpan)
    verifyToDateSpan(makeContext.resolveTopFn("today"), DateSpan.today)
    verifyToDateSpan(makeContext.resolveTopFn("lastWeek"), DateSpan.lastWeek)
    verifyToDateSpan(DateSpan.thisMonth, DateSpan.thisMonth)
    verifyToDateSpan(Date("2022-02-04"), DateSpan("2022-02-04,day"))
    verifyToDateSpan(Span(SpanMode.thisYear), DateSpan.thisYear)
    verifyToDateSpan(eval("2022-01-29..2022-02-04"), DateSpan(Date("2022-01-29"), Date("2022-02-04")))
    verifyToDateSpan(eval("2022-01-01..14day"), DateSpan(Date("2022-01-01"), Date("2022-01-14")))
    verifyToDateSpan(ObjRange(Date.yesterday.minus(1day).midnight, Date.today.midnight), DateSpan(Date.yesterday-1day, Date.yesterday))
    verifyToDateSpan(Number(2009), DateSpan.makeYear(2009))

    // Etc.toSpan
    now := DateTime.now
    s1 := Span(now-2hr, now-1hr)  // not aligned
    s2 := Span(Date.today.minus(3day).midnight, Date.today.minus(1day).midnight) // aligned
    london := TimeZone("London")
    verifyToSpan(s1, null, s1)
    verifyToSpan(s1, s1.tz, s1)
    verifyToSpan(s1, TimeZone("London"), s1)
    verifyToSpan(s2, null, s2)
    verifyToSpan(s2, s2.tz, s2)
    verifyToSpan(s2, TimeZone("London"), s2.toDateSpan.toSpan(london))
    verifyToSpan("2022-01-03,2022-02-03", null, Span.fromStr("2022-01-03,2022-02-03"))
    verifyToSpan("2022-01-03,2022-02-03", london, Span.fromStr("2022-01-03,2022-02-03", london))
    verifyToSpan(ObjRange(s1.start, s1.end), null, s1)
    verifyToSpan(ObjRange(s1.start, s1.end), london, s1)
    verifyToSpan(ObjRange(s2.start, s2.end), null, s2)
    verifyToSpan(ObjRange(s2.start.date, s2.end), null, s2)
    verifyToSpan(ObjRange(s2.start, s2.end.date-1day), null, s2)
    verifyToSpan(ObjRange(s2.start, s2.end), london, s2.toDateSpan.toSpan(london))
    verifyToSpan(ObjRange(s2.start.date, s2.end), london, s2.toDateSpan.toSpan(london))
    verifyToSpan(ObjRange(s2.start, s2.end.date-1day), london, s2.toDateSpan.toSpan(london))
    verifyToSpan(now, null, Span(now, now))
    verifyToSpan(now, london, Span(now, now))
    verifyToSpan(makeContext.resolveTopFn("today"), null, Span.today)
    verifyToSpan(Date.today, null, Span.today)
    verifyToSpan(Date.today, london, Span.today(london))
  }

  Void verifyToId(Obj? val, Obj? expected)
  {
    cx := makeContext
    if (expected != null)
    {
      actual := Etc.toId(val)
      verifyEq(actual, expected)
      verifyEq(Etc.toIds(val), Ref[expected])
      verifyEq(cx.evalToFunc("toRecId").call(cx, [val]), expected)
      verifyEq(cx.evalToFunc("toRecIdList").call(cx, [val]), Ref[expected])
    }
    else
    {
      verifyErr(CoerceErr#) { Etc.toId(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toRecId").call(cx, [val]) }
      if (val is Ref[])
      {
        verifyEq(Etc.toIds(val), val)
        verifyEq(cx.evalToFunc("toRecIdList").call(cx, [val]), val)
      }
      else if (val is Grid && ((Grid)val).isEmpty)
      {
        verifyEq(Etc.toIds(val), Ref[,])
        verifyEq(cx.evalToFunc("toRecIdList").call(cx, [val]), Ref[,])
      }
      else
      {
        verifyErr(EvalErr#) { cx.evalToFunc("toRecIdList").call(cx, [val]) }
        verifyErr(CoerceErr#) { Etc.toIds(val) }
      }
    }
  }

  Void verifyToIds(Obj? val, Ref[]? expected)
  {
    cx := makeContext
    if (expected != null)
    {
      actual := Etc.toIds(val)
      verifyEq(actual, expected)
      verifyEq(Etc.toIds(val), expected)
      verifyEq(cx.evalToFunc("toRecIdList").call(cx, [val]), expected)
    }
    else
    {
      verifyErr(CoerceErr#) { Etc.toIds(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toRecIds").call(cx, [val]) }
    }
  }

  Void verifyToRec(Obj? val, Dict? expected, Bool same := false)
  {
    cx := makeContext
    Actor.locals[ActorContext.actorLocalsKey] = cx
    if (expected != null)
    {
      actual := Etc.toRec(val)
      verifyDictEq(actual, expected)
      verifyDictEq(cx.evalToFunc("toRec").call(cx, [val]), expected)
      if (same) verifySame(actual, expected)
    }
    else
    {
      if (val is Ref || (val as List)?.first is Ref)
        verifyErr(UnknownRecErr#) { Etc.toRec(val) }
      else
        verifyErr(CoerceErr#) { Etc.toRec(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toRec").call(cx, [val]) }
    }
    Actor.locals.remove(ActorContext.actorLocalsKey)
  }

  Void verifyToRecs(Obj? val, Dict[]? expected)
  {
    cx := makeContext
    Actor.locals[ActorContext.actorLocalsKey] = cx
    if (expected != null)
    {
      actual := Etc.toRecs(val)
      verifyDictsEq(actual, expected)
      verifyDictsEq(cx.evalToFunc("toRecList").call(cx, [val]), expected)
    }
    else
    {
      if (val is Ref || (val as List)?.first is Ref)
        verifyErr(UnknownRecErr#) { Etc.toRecs(val) }
      else
        verifyErr(CoerceErr#) { Etc.toRecs(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toRecList").call(cx, [val]) }
    }
    Actor.locals.remove(ActorContext.actorLocalsKey)
  }

  Void verifyToDateSpan(Obj? val, DateSpan? expected)
  {
    cx := makeContext
    Actor.locals[ActorContext.actorLocalsKey] = cx
    if (expected != null)
    {
      actual := Etc.toDateSpan(val)
      verifyEq(actual, expected)
      verifyEq(cx.evalToFunc("toDateSpan").call(cx, [val]), expected)
    }
    else
    {
      verifyErr(CoerceErr#) { Etc.toDateSpan(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toDateSpan").call(cx, [val]) }
    }
    Actor.locals.remove(ActorContext.actorLocalsKey)
    verifyToSpan(val, null, expected?.toSpan(TimeZone.cur))
    verifyToSpan(val, TimeZone("London"), expected?.toSpan(TimeZone("London")))
  }

  Void verifyToSpan(Obj? val, TimeZone? tz, Span? expected)
  {
    cx := makeContext
    Actor.locals[ActorContext.actorLocalsKey] = cx
    if (expected != null)
    {
      actual := Etc.toSpan(val, tz)
      verifyEq(actual.start, expected.start)
      verifyEq(actual.end, expected.end)
      verifyEq(actual.tz, expected.tz)

      actual = cx.evalToFunc("toSpan").call(cx, [val, tz?.name])
      verifyEq(actual.start, expected.start)
      verifyEq(actual.end, expected.end)
      verifyEq(actual.tz, expected.tz)
    }
    else
    {
      verifyErr(CoerceErr#) { Etc.toSpan(val) }
      verifyErr(EvalErr#) { cx.evalToFunc("toSpan").call(cx, [val]) }
    }
    Actor.locals.remove(ActorContext.actorLocalsKey)
  }

//////////////////////////////////////////////////////////////////////////
// Diff
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testDiff()
  {
    db := proj.db

    // diff only - add
    Diff? d
    verifyEvalErr("""diff(null, {dis:"test", age:33})""", DiffErr#)
    verifyEvalErr("""diff({}, {dis:"test", age:33}, {add})""", ArgErr#)
    d = eval("""diff(null, {dis:"test", age:33}, {add})""")
    verifyDictEq(d.changes, ["dis":"test", "age":n(33)])
    verifyEq(d.flags, Diff.add.or(Diff.treeUpdate))

    // diff only - remove tag
    d = eval("""diff({id:@14754350-63a873e5, mod:now()}, {-age}, {transient, force})""")
    verifyDictEq(d.changes, ["age":Remove.val])
    verifyEq(d.flags, Diff.transient.or(Diff.force))

    // diff only - add with explicit id
    d = eval("""diff(null, {id:@14754350-63a873ff, dis:"makeAdd"}, {add})""")
    verifyDiffEq(d, Diff.makeAdd(["dis":"makeAdd"], Ref("14754350-63a873ff")))

    // commit+diff - add
    eval("""commit(diff(null, {dis:"diff-a", foo, i:123}, {add}))""")
    r := db.read(Filter(Str<|dis=="diff-a"|>))
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"diff-a", "foo":Marker.val, "i":n(123)])

    // commit+diff - change with tag remove, tag add, tag update
    eval("""commit(diff(readById($r.id.toCode), {-foo, i:456, s:"!"}))""")
    r = db.read(Filter(Str<|dis=="diff-a"|>))
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"diff-a", "i":n(456), "s":"!"])

    // commit+diff - makeAdd with explicit id
    xId := Ref.gen
    eval("""commit(diff(null, {id:$xId.toCode, dis:"diff-b"}, {add}))""")
    r = db.read(Filter(Str<|dis=="diff-b"|>))
    verifyDictEq(r, ["id":Ref(r.id.id, "diff-b"), "mod":r->mod, "dis":"diff-b"])

    // commit with sparse cols in grid
    eval("""[{dis:"g1", a:10}, {dis:"g2", b:20}].toGrid
            .each x => commit(diff(null, x, {add}))""")
    r = db.read(Filter(Str<|dis=="g1"|>))
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"g1", "a":n(10)])
    r = db.read(Filter(Str<|dis=="g2"|>))
    verifyDictEq(r, ["id":r.id, "mod":r->mod, "dis":"g2", "b":n(20)])

    // flags
    verifyEq( ((Diff)eval("""diff(null, {ignore}, {add})""")).flags, Diff.add.or(Diff.treeUpdate))
    verifyEq( ((Diff)eval("""readById($r.id.toCode).diff({ignore}, {remove})""")).flags, Diff.remove.or(Diff.treeUpdate))
    verifyEq( ((Diff)eval("""readById($r.id.toCode).diff({ignore}, {transient})""")).flags, Diff.transient)
    verifyEq( ((Diff)eval("""readById($r.id.toCode).diff({ignore}, {force})""")).flags, Diff.force)
    verifyEq( ((Diff)eval("""readById($r.id.toCode).diff({ignore}, {foo})""")).flags, 0)
    verifyEq( ((Diff)eval("""readById($r.id.toCode).diff({ignore}, {bypassRestricted})""")).flags, 0)
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testCommit()
  {
    db := proj.db

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
// Libs
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testLibs()
  {
    // initial state
    verifyEq(proj.libs.get("hx.math", false), null)

    // add
    rec := eval("libAdd(\"hx.math\")")
    verifyEq(proj.libs.get("hx.math").name, "hx.math")

    Grid status := eval("libs()")
    row := status.find { it->name == "hx.math" } ?: throw Err()
    verifyEq(row["name"],      "hx.math")
    verifyEq(row["libStatus"], "ok")
    verifyEq(row["libBasis"],  proj.sys.info.type.isHxd ? "sys" : "proj")

    // remove
    eval("libRemove(\"hx.math\")")
    verifyEq(proj.libs.get("math", false), null)

    // add again
    rec = eval("libAdd(\"hx.math\")")
    verifyEq(proj.libs.get("hx.math").name, "hx.math")
  }

//////////////////////////////////////////////////////////////////////////
// Exts
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testExts()
  {
    // exts
    Grid status := eval("exts()")
    row := status.find { it->name == "hx.api" } ?: throw Err()
    verifyEq(row["name"],      "hx.api")
    verifyEq(row["libBasis"],  "boot")
    verifyEq(row["extStatus"], "ok")

    // extSettingsUpdate
    eval("""extSettingsUpdate("hx.api", {foo:"bar"})""")
    verifyEq(sys.ext("hx.api").settings["foo"], "bar")

    // extSettings
    Dict dict := eval("""extSettings("hx.api")""")
    verifyEq(dict["foo"], "bar")
  }

//////////////////////////////////////////////////////////////////////////
// Companion
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testCompanion()
  {
    // add
    eval("""companionAdd({rt:"spec", name:"Foo", base:@sys::Dict, spec:@sys::Spec, doc:":-)"})""")
    spec := proj.ns.spec("proj::Foo")
    verifySame(spec, proj.ns.spec("proj::Foo"))
    verifySame(spec.base, proj.ns.spec("sys::Dict"))
    verifyEq(spec.meta["doc"], ":-)")

    // read
    rec := eval("""companionRead("Foo")""")
    verifySame(rec, proj.read("name==\"Foo\""))
    verifyEq(eval("""companionRead("Bad", false)"""), null)

    // update
    eval("""companionUpdate({rt:"spec", name:"Foo", base:@sys::Scalar, spec:@sys::Spec, doc:":-("})""")
    spec = proj.ns.spec("proj::Foo")
    verifySame(spec, proj.ns.spec("proj::Foo"))
    verifySame(spec.base, proj.ns.spec("sys::Scalar"))
    verifyEq(spec.meta["doc"], ":-(")

    // rename
    eval("""companionRename("Foo", "Bar")""")
    spec = proj.ns.spec("proj::Bar")
    verifySame(spec, proj.ns.spec("proj::Bar"))
    verifySame(spec.base, proj.ns.spec("sys::Scalar"))

    // remove
    eval("""companionRemove("Bar")""")
    verifyEq(proj.ns.spec("proj::Bar", false), null)

    // func
    Dict x := eval("""companionFunc("foo", "(a, b)=>a+b", {admin})""")
    objRef := Ref("sys::Obj")
    slots := Etc.makeMapsGrid(null, [
        ["name":"a",       "type":objRef, "maybe":m],
        ["name":"b",       "type":objRef, "maybe":m],
        ["name":"returns", "type":objRef, "maybe":m],
      ]).reorderCols(["name", "type", "maybe"])
    verifyGridEq(slots, x->slots)
    verifyDictEq(x,
      ["rt":"spec", "name":"foo", "base":Ref("sys::Func"), "spec":Ref("sys::Spec"),
        "axon":"(a, b)=>a+b", "admin":m, "slots":slots])

    // parse
    x = eval("""companionParse("Foo: Dict <abstract> { a: Obj?, b: Obj?, returns: Obj? }")""")
    verifyDictEq(x,
      ["rt":"spec", "name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"),
       "abstract":m, "slots":slots])
  }

//////////////////////////////////////////////////////////////////////////
// Filters
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testFilters()
  {
    a := addRec(["dis":"andy",    "x":n(10)])
    b := addRec(["dis":"brian",   "x":n(20), "ref":a.id])
    c := addRec(["dis":"charles", "x":n(30), "ref":a.id])
    d := addRec(["dis":"dan",     "x":n(40), "ref":b.id])

    // filterToFunc

    Row row := eval(Str<|readAll(x).find(filterToFunc(x == 20))|>)
    verifyEq(row->dis, "brian")

    Grid grid := eval(Str<|readAll(x).sort("dis").findAll(filterToFunc(x >= 30))|>)
    verifyEq(grid.size, 2)
    verifyEq(grid[0]->dis, "charles")
    verifyEq(grid[1]->dis, "dan")

    grid = eval(Str<|readAll(x).sort("dis").findAll(filterToFunc(ref->dis == "andy"))|>)
    verifyEq(grid.size, 2)
    verifyEq(grid[0]->dis, "brian")
    verifyEq(grid[1]->dis, "charles")

    Dict[] list := eval(Str<|[{x:8},{x:9},{y:1}].findAll(filterToFunc(x))|>)
    verifyEq(list.size, 2)
    verifyEq(list[0]->x, n(8))
    verifyEq(list[1]->x, n(9))

    // filter

    grid = eval(Str<|readAll(x).sort("dis").filter(x >= 30)|>)  // Grid
    verifyEq(grid.size, 2)
    verifyEq(grid[0]->dis, "charles")
    verifyEq(grid[1]->dis, "dan")

    list = eval(Str<|readAll(x).sort("dis").toRecList.filter(x >= 30)|>) // Dict[]
    verifyEq(list.size, 2)
    verifyEq(list[0]->dis, "charles")
    verifyEq(list[1]->dis, "dan")

    list = eval(Str<|[{v:1}, null, {v:2}, {v:3}, null, {v:4}].filter(v >= 3)|>) // Dict[]
    verifyEq(list.size, 2)
    verifyDictEq(list[0], ["v":n(3)])
    verifyDictEq(list[1], ["v":n(4)])

    Col[] cols := eval(Str<|readAll(x).setColMeta("dis", {foo}).setColMeta("x", {foo}).cols.filter(foo)|>) // Col[]
    verifyEq(cols.size, 2)
    verifyEq(cols[0].name, "dis")
    verifyEq(cols[1].name, "x")

    grid = eval(Str<|readAll(x).sort("dis").filter(parseFilter("x > 20"))|>) // filter + parseFilter
    verifyEq(grid.size, 2)
    verifyEq(grid[0]->dis, "charles")
    verifyEq(grid[1]->dis, "dan")

    list = eval(Str<|readAll(x).sort("dis").toRecList.filter(parseSearch("bri"))|>) // filter + parseSearch
    verifyEq(list.size, 1)
    verifyEq(list[0]->dis, "brian")
  }


//////////////////////////////////////////////////////////////////////////
// Strip Uncommittable
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testStripUncommittable()
  {
    db := proj.db

    r := addRec(["dis":"Test", "foo":m])
    db.commit(Diff(r, ["bar":"what"], Diff.transient))

    verifyDictEq(eval("stripUncommittable({foo, hisSize, curVal})"), ["foo":m])
    verifyDictEq(eval("stripUncommittable({id:@bad, connErr, point})"), ["id":Ref("bad"), "point":m])
    verifyDictEq(eval("stripUncommittable({id:@bad, connErr, point, bad:null})"), ["id":Ref("bad"), "point":m])
    verifyDictEq(eval("readById($r.id.toCode).stripUncommittable"), ["id":r.id, "dis":"Test", "foo":m])
    verifyDictEq(eval("readById($r.id.toCode).stripUncommittable({mod})"), ["id":r.id, "dis":"Test", "foo":m, "mod":r->mod])

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

  @HxTestProj
  Void testStreams()
  {
    db := proj.db

    // create test database
    a := addRec(["dis":"andy",    "age":n(10), "young":m])
    b := addRec(["dis":"brian",   "age":n(20), "young":m])
    c := addRec(["dis":"charlie", "age":n(30), "old":m])
    d := addRec(["dis":"dan",     "age":n(30), "old":m, "smart":m])
    badId := Ref.gen

    // readAllStream
    verifyStream("readAllStream(age).collect", [a, b, c, d])
    verifyStream("readAllStream(age <= 20).collect", [a, b])
    verifyStream("readAllStream(age).limit(3).collect", db.readAllList(Filter("age"))[0..2])

    // readByIdsStream
    verifyStream("readByIdsStream([$a.id.toCode, $c.id.toCode, $b.id.toCode]).collect", [a, c, b])
    verifyStream("readByIdsStream([$a.id.toCode, $c.id.toCode, $b.id.toCode]).limit(2).collect", [a, c])

    // commit
    verifyEq(eval("""(1..5).stream.map(n=>diff(null, {dis:"C-"+n, commitTest}, {add})).commit"""), n(5))
    g := db.readAll(Filter("commitTest")).sortCol("dis")
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
// Watches
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testWatches()
  {
    // create test database
    a := addRec(["dis":"a", "test":m, "foo":m])
    b := addRec(["dis":"b", "test":m, "foo":m, "bar":m])
    c := addRec(["dis":"c", "test":m, "bar":m])

    // open watch
    verifyEq(proj.watch.list.size, 0)
    Grid grid := eval("""readAll(test).watchOpen("!").sort("dis")""")
    Str watchId := grid.meta->watchId
    watch := proj.watch.get(watchId)
    watch.poll
    verifyEq(proj.watch.list.size, 1)
    verifyEq(watch.dis, "!")
    verifyEq(watch.list.size, 3)
    verifyEq(grid.size, 3)
    verifyEq(grid[0]->dis, "a")
    verifyEq(grid[1]->dis, "b")
    verifyEq(grid[2]->dis, "c")

    // verify empty poll
    grid = eval("""watchPoll($watchId.toCode)""")
    verifyEq(grid.size, 0)

    // make some changes
    a = commit(a, ["new":m])
    c = commit(c, ["new":m], Diff.transient)
    grid = eval("""watchPoll($watchId.toCode).sort("dis")""")
    verifyEq(grid.size, 2)
    verifyEq(grid[0]->dis, "a")
    verifyEq(grid[1]->dis, "c")

    // watchRemove
    verifyEq(watch.list.size, 3)
    grid = eval("""watchRemove($watchId.toCode, readAll(bar))""")
    verifyEq(watch.list.size, 1)
    a = commit(a, ["new":n(2)])
    c = commit(c, ["new":n(2)], Diff.transient)
    grid = eval("""watchPoll($watchId.toCode).sort("dis")""")
    verifyEq(grid.size, 1)
    verifyEq(grid[0]->dis, "a")
    watch = proj.watch.get(watchId)
    verifyEq(watch.list, [a.id])

    // watchAdd
    grid = eval("""watchAdd($watchId.toCode, readAll(dis=="c"))""")
    verifyEq(grid.size, 1)
    watch = proj.watch.get(watchId)
    verifyEq(watch.list.sort, [a.id, c.id].sort)

    // close watch
    eval("""watchClose($watchId.toCode)""")
    verifyEq(proj.watch.list.size, 0)
    verifyEq(watch.isClosed, true)
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testMisc()
  {
    cx := makeContext
    verifyEq(cx.user.isSu, true)
    verifyEq(cx.user.isAdmin, true)

    d := (Dict)cx.eval("about()")
    verifyEq(d->productName, sys.info.productName)
    verifyEq(d->productUri, sys.info.productUri)
    verifyEq(d->productVersion, sys.info.productVersion)

    d = (Dict)cx.eval("context()")
    verifyEq(d->userRef, cx.user.id)
    verifyEq(d->username, cx.user.username)
    verifyEq(d->locale, Locale.cur.toStr)

    cx.toDictSet("foo", "bar")
    d = (Dict)cx.eval("context()")
    verifyEq(d->foo, "bar")

    verifyEq(cx.eval("isSteadyState()"), proj.isSteadyState)
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

