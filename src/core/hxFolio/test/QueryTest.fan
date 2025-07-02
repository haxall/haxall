//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 May 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio

**
** QueryTest
**
class QueryTest : WhiteboxTest
{
  Dict? a; Dict? b; Dict? c
  Dict? d; Dict? e; Dict? f
  Dict? g; Dict? h; Dict? i
  Dict? x1; Dict? x2; Dict? x3

  Void test()
  {
    open

    a = addRec(["dis":"A", "num":n(1)])
    b = addRec(["dis":"B", "num":n(2), "fooRef":a.id])
    c = addRec(["dis":"C", "num":n(3), "fooRef":a.id, "bar":"a"])
    d = addRec(["dis":"D", "num":n(4), "fooRef":a.id, "bar":"b"])
    e = addRec(["dis":"E", "num":n(5), "fooRef":b.id, "bar":"c"])
    f = addRec(["dis":"F", "num":n(6), "fooRef":b.id, "bar":"d"])
    g = addRec(["dis":"G", "num":n(7), "baz":m])

    // trash
    x1 = addRec(["dis":"X1", "num":n(8),  "fooRef":b.id, "bar":"x", "trash":m])
    x2 = addRec(["dis":"X2", "num":n(9),  "fooRef":b.id, "bar":"x", "trash":m])
    x3 = addRec(["dis":"X3", "num":n(10), "fooRef":b.id, "bar":"x", "trash":m])

    // first do tests with no indices
    doTest(false)

    // make some modifications to trash by moving stuff into and
    // out of index, but leave things the same overall
    x1 = commit(x1, ["num":n(11), "bar":"c"])
    x2 = commit(x2, ["trash":Remove.val])
    c  = commit(c,  ["trash":m])
    x2 = commit(x2, ["trash":m])
    c  = commit(c,  ["trash":Remove.val])

    close
  }

  Void doTest(Bool indexed)
  {
    verifyQuery("outOfThsWorld", [,], "fullScan")
    verifyQuery("outOfThsWorld and fooBar", [,], "fullScan")
    verifyQuery("outOfThsWorld or fooBar", [,], "fullScan")

    verifyQuery("id==$b.id.toCode",      [b],  "byId")
    verifyQuery("id==${Ref.gen.toCode}", [,],  "byId")
    verifyQuery("id==`uri-not-id`",      [,],  "byId")
    verifyQuery("id==$b.id.toCode and num==2",  [b], "byId")
    verifyQuery("id==$b.id.toCode and num!=2",  [,], "byId")
    verifyQuery("x and id==$b.id.toCode and y", [,], "byId")

    verifyQuery("num",         [a, b, c, d, e, f, g], indexed ? "tagMatch:num"   : "fullScan")
    verifyQuery("num > 4",     [e, f, g],             indexed ? "tagScan:num"    : "fullScan")
    verifyQuery("num >= 4",    [d, e, f, g],          indexed ? "tagScan:num"    : "fullScan")
    verifyQuery("num <= 4",    [a, b, c, d],          indexed ? "tagScan:num"    : "fullScan")
    verifyQuery("num < 4",     [a, b, c],             indexed ? "tagScan:num"    : "fullScan")
    verifyQuery("num == 4",    [d],                   indexed ? "tagValMatch:num": "fullScan")
    verifyQuery("num != 4",    [a, b, c, e, f, g],    indexed ? "tagScan:num"    : "fullScan")
    verifyQuery("num == 99",   [,],                   indexed ? "empty"          : "fullScan")
    verifyQuery("num > 99",    [,],                   indexed ? "tagScan:num"    : "fullScan")
    verifyQuery("num > `foo`", [,],                   indexed ? "tagScan:num"    : "fullScan")
    verifyQuery("not num",     [,],                   "fullScan")
    verifyQuery("not fooBar",  [a, b, c, d, e, f, g], "fullScan")

    aId := a.id.toCode
    bId := b.id.toCode
    verifyQuery("fooRef",          [b, c, d, e, f], indexed ? "tagMatch:fooRef"       : "fullScan")
    verifyQuery("fooRef == $aId",  [b, c, d],       indexed ? "tagValMatch:fooRef"    : "fullScan")
    verifyQuery("fooRef == $bId",  [e, f],          indexed ? "tagValMatch:fooRef"    : "fullScan")
    verifyQuery("fooRef == @xxxx", [,],             indexed ? "empty"                 : "fullScan")
    verifyQuery("fooRef != $aId",  [e, f],          indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef != @xxxx", [b, c, d, e, f], indexed ? "tagScan:fooRef"        : "fullScan")

    verifyQuery("fooRef->num==1", [b, c, d],        indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef->num>=1", [b, c, d, e, f],  indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef->num>1",  [e, f],           indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef->xxx",    [,],              indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef->dis",    [b, c, d, e, f],  indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef->dis==\"B\"", [e, f],       indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef->fooRef", [e, f],           indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("fooRef->badone", [,],              indexed ? "tagScan:fooRef"        : "fullScan")
    verifyQuery("not fooRef->dis", [a, g],          "fullScan")

    verifyQuery("num and fooRef",           [b, c, d, e, f], indexed ? "tagScan:fooRef"       : "fullScan")
    verifyQuery("fooRef and num",           [b, c, d, e, f], indexed ? "tagScan:fooRef"       : "fullScan")
    verifyQuery("num and bar",              [c, d, e, f],    indexed ? "tagScan:bar"          : "fullScan")
    verifyQuery("bar and num",              [c, d, e, f],    indexed ? "tagScan:bar"          : "fullScan")
    verifyQuery("num and fooRef and bar",   [c, d, e, f],    indexed ? "tagScan:bar"          : "fullScan")
    verifyQuery("bar and num and fooRef",   [c, d, e, f],    indexed ? "tagScan:bar"          : "fullScan")
    verifyQuery("fooRef==$aId and bar",     [c, d],          indexed ? "tagValScan:fooRef" : "fullScan")
    verifyQuery("fooRef==@xxx and bar",     [,],             indexed ? "empty"                : "fullScan")
    verifyQuery("fooRef->num>1 and num",    [e, f],          indexed ? "tagScan:fooRef"       : "fullScan")
    verifyQuery("fooRef->num>1 and num==6", [f],             indexed ? "tagValScan:num"       : "fullScan")
    verifyQuery("fooRef->dis and bar",        [c, d,e,f],    indexed ? "tagScan:bar"          : "fullScan")
    verifyQuery("fooRef->dis and bar==\"b\"", [d],           indexed ? "tagValScan:bar"       : "fullScan")
    verifyQuery("fooRef->dis and bar>=\"b\"", [d,e,f],       indexed ? "tagScan:bar"          : "fullScan")

    verifyQuery("fooRef or bar",           [b, c, d, e, f],     "fullScan")
    verifyQuery("fooRef or bar or baz",    [b, c, d, e, f, g],  "fullScan")
    verifyQuery("(fooRef and bar) or baz", [c, d, e, f, g],     "fullScan")

    verifyQuery("^baz",     [g],          "fullScan")
    verifyQuery("^num-bar", [c, d, e, f], "fullScan")
    verifyQuery("^bar-num", [c, d, e, f], "fullScan")

    verifyQuery("trash",                 [x1, x2, x3], "fullScan", true)
    verifyQuery("trash and num",         [x1, x2, x3], "fullScan", true)
    verifyQuery("num >= 8",              [x1, x2, x3], "fullScan", true)
    verifyQuery("trash and num >= 8",    [x1, x2, x3], "fullScan", true)
    verifyQuery("num == 9 or num == 10", [x2, x3],     "fullScan", true)
    verifyQuery("num >= 8 and fooRef",   [x1, x2, x3], "fullScan", true)
  }

  Void verifyQuery(Str filterStr, Dict[] expected, Str plan, Bool trash := false)
  {
    folio.stats.clear
    statsA := folio.stats.reads.count

    // readAllList
    opts := trash ? Etc.dict1("trash", m) : null
    filter := Filter(filterStr)
    list := folio.readAllList(filter, opts)
    // echo(">> $filter $list.size ?= $expected.size")
    verifyDictsEq(list, expected, false)
    verifyPlanStats(plan)

    // readAll
    grid := folio.readAll(filter, opts)
    verifyDictsEq(grid.toRows, expected, false)
    verifyPlanStats(plan)

    statsB := folio.stats.reads.count

    // readCount
    count := folio.readCount(filter, opts)
    verifyEq(count, expected.size)
    verifyPlanStats(plan)

    statsC := folio.stats.reads.count

    // readAllEachWhile
    acc := Dict[,]
    ew := folio.readAllEachWhile(filter, opts) |rec| { acc.add(rec); return null }
    verifyEq(ew, null)
    verifyDictsEq(acc, expected, false)
    verifyPlanStats(plan)

    statsD := folio.stats.reads.count

    // check stats
    verifyEq(statsB, statsA + 2)
    verifyEq(statsC, statsB + 1)
    verifyEq(statsD, statsC + 1)

    // skip rest of tests if trash
    if (trash) return

    // read
    if (expected.isEmpty)
    {
      verifyEq(folio.read(filter, false), null)
      verifyErr(UnknownRecErr#) { folio.read(filter) }
    }
    else
    {
      single := folio.read(filter)
      verifyDictEq(expected.find |s| { s.id == single.id }, single)
    }
    verifyPlanStats(plan)

    // with limit option
    if (expected.size > 2)
    {
      limit := (1..expected.size).random
      opts = Etc.makeDict(["limit":n(limit)])
      limited := list[0..<limit]
      verifyDictsEq(folio.readAllList(filter, opts), limited, true)
      verifyDictsEq(folio.readAll(filter, opts).toRows, limited, true)
      verifyEq(folio.readCount(filter, opts), limit)
      verifyPlanStats(plan)
    }
  }

  Void verifyPlanStats(Str plan)
  {
    acc := Str:StatsCountAndTicks[:]
    folio.stats.readsByPlan.each |v, p| {acc[p] = v }
    // echo(" $plan ?= $acc")
    verifyEq(acc.size, 1)
    verifyEq(acc.keys.first, plan)
    folio.stats.readsByPlan.clear
  }

//////////////////////////////////////////////////////////////////////////
// QueryAcc
//////////////////////////////////////////////////////////////////////////

  Void testQueryAcc()
  {
    a := Etc.makeDict(["dis":"A", "num":n(1), "a":m])
    b := Etc.makeDict(["dis":"B", "num":n(2), "b":m])
    c := Etc.makeDict(["dis":"C", "num":n(3), "c":m])
    d := Etc.makeDict(["dis":"D", "num":n(4), "d":m])
    x := [a, b, c, d]

    // null cx, different limits
    verifyQueryAcc(null, 10, x, [a, b, c, d])
    verifyQueryAcc(null,  4, x, [a, b, c, d])
    verifyQueryAcc(null,  3, x, [a, b, c])
    verifyQueryAcc(null,  2, x, [a, b])
    verifyQueryAcc(null,  1, x, [a])
    verifyQueryAcc(null,  0, x, [,])

    // filtered cx, different limits
    cx := QueryTestContext(Filter("dis"))
    verifyQueryAcc(cx, 10, x, [a, b, c, d])
    verifyQueryAcc(cx,  4, x, [a, b, c, d])
    verifyQueryAcc(cx,  3, x, [a, b, c])
    verifyQueryAcc(cx,  2, x, [a, b])
    verifyQueryAcc(cx,  1, x, [a])
    verifyQueryAcc(cx,  0, x, [,])

    // filtered cx, different limits
    cx = QueryTestContext(Filter("num <= 2"))
    verifyQueryAcc(cx, 10, x, [a, b])
    verifyQueryAcc(cx,  4, x, [a, b])
    verifyQueryAcc(cx,  3, x, [a, b])
    verifyQueryAcc(cx,  2, x, [a, b])
    verifyQueryAcc(cx,  1, x, [a])
    verifyQueryAcc(cx,  0, x, [,])

    // filtered cx, different limits
    cx = QueryTestContext(Filter("num == 3"))
    verifyQueryAcc(cx, 10, x, [c])
    verifyQueryAcc(cx,  4, x, [c])
    verifyQueryAcc(cx,  3, x, [c])
    verifyQueryAcc(cx,  2, x, [c])
    verifyQueryAcc(cx,  1, x, [c])
    verifyQueryAcc(cx,  0, x, [,])
  }

  Void verifyQueryAcc(FolioContext? cx, Int limit, Dict[] x, Dict[] expected)
  {
    // collect
    opts := QueryOpts(limit)
    collect := QueryCollect(cx, opts)
    x.each |r, i| { verifyEq(collect.add(r), collect.list.size < limit) }
    verifyDictsEq(collect.list, expected)

    // count
    count := QueryCounter(cx, opts)
    x.each |r, i| { verifyEq(count.add(r), count.count < limit) }
    verifyEq(count.count, expected.size)

    // each while
    eAcc := Dict[,]
    e := QueryEachWhile(cx, opts) |rec->Obj?| { eAcc.add(rec); return null }
    x.each |r, i| { verifyEq(e.add(r), eAcc.size < limit) }
    verifyDictsEq(eAcc, expected)

    // each while using early break instead of limit
    eAcc = Dict[,]
    broke := false
    e = QueryEachWhile(cx, QueryOpts(Int.maxVal)) |rec->Obj?|
    {
      if (eAcc.size < limit) eAcc.add(rec)
      broke = eAcc.size >= limit
      return broke ? "break" : null
    }
    x.each |r, i| { e.add(r) }
    verifyDictsEq(eAcc, expected)
    verifyEq(e.result, broke ? "break" : null)
  }

}

**************************************************************************
** QueryTestContext
**************************************************************************

internal class QueryTestContext : FolioContext
{
  new make(Filter f) { readFilter = f }
  const Filter readFilter
  override Bool canRead(Dict rec) { readFilter.matches(rec, HaystackContext.nil) }
  override  Bool canWrite(Dict rec) { true }
  override Obj? commitInfo() { null }
}

