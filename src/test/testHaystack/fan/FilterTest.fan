//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jan 2009  Brian Frank  Creation
//   24 Aug 2009  Brian Frank  Rename QueryTest => FilterTest
//   18 Feb 2016  Brian Frank  Move from proj => testHaystack
//

using haystack

**
** FilterTest
**
@Js
class FilterTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// Path
//////////////////////////////////////////////////////////////////////////

  Void testPath()
  {
    verifyPath("a", ["a"])
    verifyPath("foo_bar", ["foo_bar"])
    verifyPath("foo123", ["foo123"])
    verifyPath("a->b", ["a", "b"])
    verifyPath("a->b->c", ["a", "b", "c"])
    verifyPath("foo_bar->x23_longer", ["foo_bar", "x23_longer"])

    verifyNull(FilterPath.fromStr("x-y", false))
    verifyErr(ParseErr#) { x := FilterPath.fromStr("x-") }
    verifyErr(ParseErr#) { x := FilterPath.fromStr("x->", true) }
    verifyErr(ParseErr#) { x := FilterPath.fromStr("x->->y", true) }
  }

  Void verifyPath(Str str, Str[] names)
  {
    p := FilterPath(str)
    verifyEq(p.size, names.size)
    names.each |n, i| { verifyEq(n, p[i]) }
    verifyErr(IndexErr#) { p.get(names.size) }
    verifyEq(p.toStr, names.join("->"))
    verifyEq(FilterPath.fromStr(p.toStr), p)
    if (names.size == 1)
      verifyEq(p.typeof.qname, "haystack::FilterPath1")
    else
      verifyEq(p.typeof.qname, "haystack::FilterPathN")
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  Void testIdentity()
  {
    verifyEq(Filter.has("a"), Filter.has("a"))
    verifyNotEq(Filter.has("a"), Filter.has("b"))
  }

//////////////////////////////////////////////////////////////////////////
// Parse
//////////////////////////////////////////////////////////////////////////

  Void testParse()
  {
    // has
    verifyParse("foo", Filter.has("foo"), "foo", ["foo"])
    verifyParse("foo->bar", Filter.has("foo->bar"), "foo->bar", ["foo"])
    verifyParse("foo->bar->baz", Filter.has("foo->bar->baz"), "foo->bar->baz", ["foo"])
    verifyParse("fooBar", Filter.has("fooBar"), "fooBar", ["fooBar"])
    verifyParse("foo7Bar", Filter.has("foo7Bar"), "foo7Bar", ["foo7Bar"])
    verifyParse("not", Filter.has("not"), "not", ["not"], "\"not\"")
    verifyParse("and", Filter.has("and"), "and", ["and"], "\"and\"")
    verifyParse("or", Filter.has("or"), "or", ["or"], "\"or\"")

    // missing
    verifyParse("not foo", Filter.missing("foo"), "not foo", ["foo"])
    verifyParse(" not  foo->bar ", Filter.missing("foo->bar"), "not foo->bar", ["foo"])
    verifyParse("not not", Filter.missing("not"), "not not", ["not"], "not \"not\"")

    // bool literals
    verifyParse("x==true", Filter.eq("x", true), "x == ?", ["x"])
    verifyParse("x==false", Filter.eq("x", false), "x == ?", ["x"])

    // str literals
    verifyParse("x==\"hi\"", Filter.eq("x", "hi"), "x == ?", ["x"])
    verifyParse("x!=\"\\\"hi\\\"\"",  Filter.ne("x", "\"hi\""), "x != ?", ["x"])
    verifyParse(" x ==  \"_\\uabcd_\\n_\"", Filter.eq("x", "_\uabcd_\n_"), "x == ?", ["x"])
    verifyParse("x->y->z==\"hi\"", Filter.eq("x->y->z", "hi"), "x->y->z == ?", ["x"])
    verifyParse("not==\"hi\"", Filter.eq("not", "hi"), "not == ?", ["not"], "\"not\"==\"hi\"")

    // uri literals
    verifyParse("uri==`http://foo/?bar`", Filter.eq("uri", `http://foo/?bar`), "uri == ?", ["uri"])
    verifyParse("uri==`file name`", Filter.eq("uri", `file name`), "uri == ?", ["uri"])
    verifyParse("uri == `foo bar`", Filter.eq("uri", `foo bar`), "uri == ?", ["uri"])

    // int literals
    verifyParse("num < 4", Filter.lt("num", n(4)), "num < ?", ["num"])
    verifyParse("num <= -99", Filter.le("num", n(-99)), "num <= ?", ["num"])
    verifyParse("num > 0xabcd", Filter.gt("num", n(0xabcd)), "num > ?", ["num"])
    verifyParse("num >= 0xabcd_0123", Filter.ge("num", n(0xabcd_0123)), "num >= ?", ["num"])

    // float literals
    verifyParse("num < 4.0", Filter.lt("num", n(4f)), "num < ?", ["num"])
    verifyParse("num <= -9.4", Filter.le("num", n(-9.4f)), "num <= ?", ["num"])
    verifyParse("num > 4e5", Filter.gt("num", n(4e5f)), "num > ?", ["num"])
    verifyParse("num >= 1.6e+4", Filter.ge("num", n(1.6e+4f)), "num >= ?", ["num"])
    verifyParse("num >= 1.6e-8", Filter.ge("num", n(1.6e-8f)), "num >= ?", ["num"])
    verifyParse("s->num >= 1.6e-8", Filter.ge("s->num", n(1.6e-8f)), "s->num >= ?", ["s"])

    // unit literals
    verifyParse("x < 5ns", Filter.lt("x", n(5,"ns")), "x < ?", ["x"])
    verifyParse("x < 10kg", Filter.lt("x", n(10, "kg")), "x < ?", ["x"])
    verifyParse("x < -9sec", Filter.lt("x", n(-9, "sec")), "x < ?", ["x"])
    verifyParse("x < 2.5hr", Filter.lt("x", n(2.5f, "hr")), "x < ?", ["x"])

    // date, time, datetime
    verifyParse("foo < 2009-10-30", Filter.lt("foo", Date("2009-10-30")), "foo < ?", ["foo"])
    verifyParse("foo < 8:30", Filter.lt("foo", Time("08:30:00")), "foo < ?", ["foo"])
    verifyParse("foo < 13:00:00", Filter.lt("foo", Time("13:00:00")), "foo < ?", ["foo"])
    dt := DateTime("2016-02-22T08:43:12.905-05:00 New_York")
    verifyParse("foo < $dt", Filter.lt("foo", dt), "foo < ?", ["foo"],
      "foo < dateTime($dt.date, $dt.time, $dt.tz.name.toCode)")

    // ref literals
    id := Ref.gen
    verifyParse("author == $id.toCode", Filter.eq("author", id), "author == ?", ["author"])
    id = Ref("foo:bar-baz")
    verifyParse("author == $id.toCode", Filter.eq("author", id), "author == ?", ["author"])
    id = Ref("1ec5d86e-8ea2ba5a")
    verifyParse("id==$id.toCode", Filter.eq("id", id), "id == ?", ["id"])

    // and
    verifyParse("a and b", Filter.has("a").and(Filter.has("b")), "(a) and (b)", ["a", "b"])
    verifyParse("a and b and c == 3", Filter.has("a").and(Filter.has("b")).and(Filter.eq("c", n(3))), "((a) and (b)) and (c == ?)", ["a", "b", "c"])

    // or
    verifyParse("a or b", Filter.has("a").or(Filter.has("b")), "(a) or (b)", ["a", "b"])
    verifyParse("a or b or c == 3", Filter.has("a").or(Filter.has("b")).or(Filter.eq("c", n(3))), "((a) or (b)) or (c == ?)", ["a", "b", "c"])

    // parens
    verifyParse("(a)", Filter.has("a"), "a", ["a"])
    verifyParse("(a) and (b)", Filter.has("a").and(Filter.has("b")), "(a) and (b)", ["a", "b"])
    verifyParse("(a) or (b) or (c == 3)", Filter.has("a").or(Filter.has("b")).or(Filter.eq("c", n(3))), "((a) or (b)) or (c == ?)", ["a", "b", "c"])

    // isA
    verifyParse("^air-output", Filter.isA(Symbol("air-output")), "^air-output", Str[,])

    // combo
    isA := Filter.has("a")
    isB := Filter.has("b")
    isC := Filter.has("c")
    isD := Filter.has("d")
    verifyParse("a and b or c", (isA.and(isB)).or(isC), "(c) or ((a) and (b))", ["c", "a", "b"])
    verifyParse("a or b and c", isA.or(isB.and(isC)), "(a) or ((b) and (c))", ["a", "b", "c"])
    verifyParse("a and b or c and d", (isA.and(isB)).or(isC.and(isD)), "((a) and (b)) or ((c) and (d))", ["a", "b", "c", "d"])
    verifyParse("a and (b or c) and d", isA.and(isD).and(isB.or(isC)), "((a) and (d)) and ((b) or (c))", ["a", "d", "b", "c"])
    verifyParse("a or (b and c) or d", isA.or(isD).or(isB.and(isC)), "((a) or (d)) or ((b) and (c))", ["a", "d", "b", "c"])

    // comments
    verifyParse("a // and foo==5", isA, "a", ["a"])
  }

  virtual Filter verifyParse(Str s, Filter expected, Str pattern, Str[] tags, Str axon := s)
  {
    // fromStr
    actual := Filter(s)
    verifyEq(actual, expected)

    // pattern
    verifyEq(actual.pattern, pattern)

    // tags
    tagAcc := Str[,]
    actual.eachTag |x| { tagAcc.add(x) }
    verifyEq(tagAcc, tags)
    return actual
  }

//////////////////////////////////////////////////////////////////////////
// eachTag and eachVal
//////////////////////////////////////////////////////////////////////////

  Void testEach()
  {
    x := Ref("x")
    y := Ref("y")
    z := Ref("z")

    verifyEach("foo",        ["foo"], Obj[,])
    verifyEach("not foo",    ["foo"], Obj[,])
    verifyEach("foo == @x",  ["foo"], Obj[x])
    verifyEach("foo != @x",  ["foo"], Obj[x])
    verifyEach("foo < 123",  ["foo"], Obj[n(123)])
    verifyEach("foo > 123",  ["foo"], Obj[n(123)])
    verifyEach("foo >= 123", ["foo"], Obj[n(123)])
    verifyEach("foo <= 123", ["foo"], Obj[n(123)])

    verifyEach("foo == @x and bar == @y", ["bar", "foo"], Obj[y, x])
    verifyEach("foo == @x or bar == @y",  ["bar", "foo"], Obj[y, x])

    verifyEach("(foo == @x and bar == @y) or (baz == @z)",  ["baz", "bar", "foo"], Obj[z, y, x])
  }

  Void verifyEach(Str s, Str[] expectedTags, Obj[] expectedVals)
  {
    actualTags := Str[,]
    actualVals := Obj[,]
    f := Filter(s)
    f.eachTag |x| { actualTags.add(x) }
    f.eachVal |x| { actualVals.add(x) }
    verifyEq(expectedTags, actualTags)
    verifyEq(expectedVals, actualVals)
  }

//////////////////////////////////////////////////////////////////////////
// Pathing
//////////////////////////////////////////////////////////////////////////

  Void testPathing()
  {
    f := verifyParse("a->b", Filter.has("a->b"), "a->b", ["a"])
    p := (FilterPath)f.argA
    verifyEq(p.get(0), "a")
    verifyEq(p.get(1), "b")
    verifyEq(p.size, 2)

    f = verifyParse("a->b->c", Filter.has("a->b->c"), "a->b->c", ["a"])
    p = (FilterPath)f.argA
    verifyEq(p.get(0), "a")
    verifyEq(p.get(1), "b")
    verifyEq(p.get(2), "c")
    verifyEq(p.size, 3)

    f = verifyParse("not a->b->c->d", Filter.missing("a->b->c->d"), "not a->b->c->d", ["a"])
    p = (FilterPath)f.argA
    verifyEq(p.get(0), "a")
    verifyEq(p.get(1), "b")
    verifyEq(p.get(2), "c")
    verifyEq(p.get(3), "d")
    verifyEq(p.size, 4)

    verifyParse("a->b == 2", Filter.eq("a->b", n(2)), "a->b == ?", ["a"])
    verifyParse("a->b != 2", Filter.ne("a->b", n(2)), "a->b != ?", ["a"])
    verifyParse("a->b < 2",  Filter.lt("a->b", n(2)), "a->b < ?",  ["a"])
    verifyParse("a->b <= 2", Filter.le("a->b", n(2)), "a->b <= ?", ["a"])
    verifyParse("a->b >= 2", Filter.ge("a->b", n(2)), "a->b >= ?", ["a"])
    verifyParse("a->b > 2",  Filter.gt("a->b", n(2)), "a->b > ?",  ["a"])
  }

//////////////////////////////////////////////////////////////////////////
// Parse Errs
//////////////////////////////////////////////////////////////////////////

  Void testParseErrs()
  {
    verifyParseErr("")
    verifyParseErr("n:")
    verifyParseErr("n-foo")
    verifyParseErr("n->")
    verifyParseErr("(x")
    verifyParseErr("(x and")
    verifyParseErr("n==")
    verifyParseErr("n==\"..")
    verifyParseErr("n==`..")
    verifyParseErr("foo==Foo(\"xxx\")")
    verifyParseErr("n=3x5")
  }

  Void verifyParseErr(Str s)
  {
    verifyEq(Filter.fromStr(s, false), null)
    verifyErr(ParseErr#) { x := Filter(s) }
    try
    {
      x := Filter.fromStr(s, true)
      fail
    }
    catch (ParseErr e) {} // echo("  $s  =>  $e")
  }

//////////////////////////////////////////////////////////////////////////
// Compare
//////////////////////////////////////////////////////////////////////////

  Void testCompare()
  {
    verify(Filter("x == 5") < Filter("y == 5"))
    verify(Filter("x == 7") > Filter("x == 6"))
    verifyEq(Filter("x == 7") <=> Filter("x == 7"), 0)

    verify(Filter("a") < Filter("b"))
    verify(Filter("x == 4.0") > Filter("b"))

    verify(Filter("bar and x == 5") < Filter("isFoo and x == 5"))
    verify(Filter("bar and x == 5") < Filter("bar and y == 5"))
    verifyEq(Filter("x == 5 and bar") <=> Filter("bar and x == 5"), 0)
  }

//////////////////////////////////////////////////////////////////////////
// Pattern
//////////////////////////////////////////////////////////////////////////

  Void testPattern()
  {
    verifyPattern("x == 4 and y == 5", "(x == ?) and (y == ?)")
    verifyPattern("y == 4 and x == 5", "(x == ?) and (y == ?)")

    verifyPattern("fooBar and name==\"foo\"", "(fooBar) and (name == ?)")
    verifyPattern("name==\"foo\" and fooBar", "(fooBar) and (name == ?)")

    verifyPattern("foo and x < 20 and x > 10", "((foo) and (x > ?)) and (x < ?)")
    verifyPattern("foo and x > 10 and x < 20", "((foo) and (x > ?)) and (x < ?)")
    verifyPattern("x > 10 and x < 20 and foo", "((foo) and (x > ?)) and (x < ?)")
    verifyPattern("x > 10 and foo and x < 20", "((foo) and (x > ?)) and (x < ?)")

    verifyPattern("z == 5 and hasx and foo and y==false and bar",
                  "((((bar) and (foo)) and (hasx)) and (y == ?)) and (z == ?)")
    verifyPattern("(z == 5 or x == 6) and (isFoo or bar)",
                  "((bar) or (isFoo)) and ((x == ?) or (z == ?))")
    verifyPattern("(bar or isFoo) and (x == 5 or z == 77)",
                  "((bar) or (isFoo)) and ((x == ?) or (z == ?))")

    verifyPattern("ahu and siteRef==@15289237-095cd7b1", "(ahu) and (siteRef == ?)")
    verifyPattern("siteRef==@15289237-095cd7b1 and ahu", "(ahu) and (siteRef == ?)")

    // hand build a deep tree
    a := Filter.has("e").and(Filter.has("d"))
    b := Filter.has("f").and(Filter.has("a"))
    c := Filter.has("c")
    d := Filter.has("b")
    q := (a.and(b)).and(c.and(d))
    verifyEq(q.pattern, "(((((a) and (b)) and (c)) and (d)) and (e)) and (f)")
    q = (a.and(b)).or(c.and(d))
    verifyEq(q.pattern, "((b) and (c)) or ((((a) and (d)) and (e)) and (f))")
  }

  Void verifyPattern(Str s, Str pattern)
  {
    verifyEq(Filter(s).pattern, pattern)
  }

//////////////////////////////////////////////////////////////////////////
// Include
//////////////////////////////////////////////////////////////////////////

  Void testInclude()
  {
    a := Etc.makeDict(["dis":"a", "num":n(10), "date":Date("2016-01-01"), "foo":"baz"])
    b := Etc.makeDict(["dis":"b", "num":n(20), "date":Date("2016-01-02"), "foo":n(12), "ref":Ref("a")])
    c := Etc.makeDict(["dis":"c", "num":n(30), "date":Date("2016-01-03"), "foo":n(13), "ref":Ref("b"), "thru":"c"])
    d := Etc.makeDict(["dis":"d", "num":n(30), "date":Date("2016-01-03"), "ref":Ref("c")])
    e := Etc.makeDict(["dis":"e", "num":n(40), "date":Date("2016-01-06"), "ref":Etc.makeDict(["thru":"e"])])
    recs := [a, b, c, d, e]

    verifyInclude(recs, Str<|dis|>, [a, b, c, d, e])
    verifyInclude(recs, Str<|foo|>, [a, b, c])

    verifyInclude(recs, Str<|not dis|>, [,])
    verifyInclude(recs, Str<|not foo|>, [d, e])

    verifyInclude(recs, Str<|dis  ==  "c"|>, [c])
    verifyInclude(recs, Str<|num==30|>, [c, d])
    verifyInclude(recs, Str<|date==2016-01-02|>, [b])
    verifyInclude(recs, Str<|foo==12|>, [b])

    verifyInclude(recs, Str<|dis !=  "c"|>, [a, b, d, e])
    verifyInclude(recs, Str<|num!=30|>, [a, b, e])
    verifyInclude(recs, Str<|date != 2016-01-02|>, [a, c, d, e])
    verifyInclude(recs, Str<|foo != 13|>, [a, b])

    verifyInclude(recs, Str<|dis < "c"|>, [a, b])
    verifyInclude(recs, Str<|num < 20|>, [a])
    verifyInclude(recs, Str<|date < 2016-01-04|>, [a, b, c, d])
    verifyInclude(recs, Str<|foo < 13|>, [b])
    verifyInclude(recs, Str<|foo < "c"|>, [a])

    verifyInclude(recs, Str<|dis <= "c"|>, [a, b, c])
    verifyInclude(recs, Str<|num <= 20|>, [a, b])
    verifyInclude(recs, Str<|date <= 2016-01-02|>, [a, b])
    verifyInclude(recs, Str<|foo <= 13|>, [b, c])
    verifyInclude(recs, Str<|foo <= "baz"|>, [a])

    verifyInclude(recs, Str<|dis > "c"|>, [d, e])
    verifyInclude(recs, Str<|num > 20|>, [c, d, e])
    verifyInclude(recs, Str<|date > 2016-01-02|>, [c, d, e])
    verifyInclude(recs, Str<|foo > 12|>, [c])
    verifyInclude(recs, Str<|foo > "a"|>, [a])

    verifyInclude(recs, Str<|dis >= "c"|>, [c, d, e])
    verifyInclude(recs, Str<|num >= 20|>, [b, c, d, e])
    verifyInclude(recs, Str<|date >= 2016-01-02|>, [b, c, d, e])
    verifyInclude(recs, Str<|foo >= 12|>, [b, c])
    verifyInclude(recs, Str<|foo >= "baz"|>, [a])

    verifyInclude(recs, Str<|dis=="c" or num==30|>, [c, d])
    verifyInclude(recs, Str<|dis=="c" and num==30|>, [c])
    verifyInclude(recs, Str<|dis=="c" or num==30 or dis=="b"|>, [b, c, d])
    verifyInclude(recs, Str<|dis=="c" and num==30 and foo==13|>, [c])
    verifyInclude(recs, Str<|dis=="c" and num==30 and foo==12|>, [,])
    verifyInclude(recs, Str<|dis=="c" and num==30 or foo==12|>, [b, c])
    verifyInclude(recs, Str<|(dis=="c" or num==30) and not foo|>, [d])
    verifyInclude(recs, Str<|(num==30 and foo) or (num <= 10)|>, [a, c])

    verifyInclude(recs, Str<|ref->dis=="a"|>, [b])
    verifyInclude(recs, Str<|ref->ref->dis=="a"|>, [c])
    verifyInclude(recs, Str<|ref->ref->ref->dis=="a"|>, [d])
    verifyInclude(recs, Str<|ref->num <= 20|>, [b, c])
    verifyInclude(recs, Str<|ref->thru|>, [d, e])
    verifyInclude(recs, Str<|ref->thru=="e"|>, [e])

    verifyInclude(recs, Str<|^foo-bar|>, [,])
    verifyInclude(recs, Str<|^foo|>, [a,b,c])
    verifyInclude(recs, Str<|^foo-thru|>, [c])
  }

  Void testIncludeList()
  {
    aId := Ref("a")
    bId := Ref("b")
    cId := Ref("c")
    dId := Ref("d")
    a := Etc.makeDict(["dis":"a", "str":"q",        "ref":aId])
    b := Etc.makeDict(["dis":"b", "str":["q"],      "ref":[aId]])
    c := Etc.makeDict(["dis":"c", "str":["q", "r"], "ref":[aId, bId]])
    d := Etc.makeDict(["dis":"d", "str":"q",        "ref":[bId, cId]])
    e := Etc.makeDict(["dis":"e", "refx":cId])
    f := Etc.makeDict(["dis":"f", "refx":[cId]])
    g := Etc.makeDict(["dis":"g", "refx":[dId]])
    h := Etc.makeDict(["dis":"h", "refx":[cId, dId]])
    recs := [a, b, c, d, e, f, g, h]

    // lists of non-refs don't get special treatment
    verifyInclude(recs, Str<|str=="q"|>,      [a, d])

    // verify lists of refs
    verifyInclude(recs, Str<|ref==@a|>,        [a, b, c])
    verifyInclude(recs, Str<|ref->dis=="a"|>,  [a, b, c])
    verifyInclude(recs, Str<|refx|>,           [e, f, g, h])
    verifyInclude(recs, Str<|refx==@c|>,       [e, f, h])
    verifyInclude(recs, Str<|refx->dis=="c"|>, [e, f, h])
    verifyInclude(recs, Str<|refx->ref|>,      [e, f, g, h])
    verifyInclude(recs, Str<|refx->ref==@a|>,  [e, f, h])
  }

  Void testIncludeDateTime()
  {
    tz := TimeZone("New_York")
    a := Etc.makeDict(["ts": Date("2020-09-01").toDateTime(Time(1, 0), tz)])
    b := Etc.makeDict(["ts": Date("2020-09-01").toDateTime(Time(2, 0), tz)])
    c := Etc.makeDict(["ts": Date("2020-09-02").toDateTime(Time(3, 0), tz)])
    d := Etc.makeDict(["ts": Date("2020-09-02").toDateTime(Time(4, 0), tz)])
    e := Etc.makeDict(["ts": Date("2020-09-03").toDateTime(Time(2, 0), tz)])
    recs := [a, b, c, d, e]

    // no/bad path
    verifyInclude(recs, Str<|ts==2020-09-02|>,  [,])
    verifyInclude(recs, Str<|ts == "New_York"|>,  [,])
    verifyInclude(recs, Str<|ts->bad == 2020-09-02|>,  [,])

    // date
    verifyInclude(recs, Str<|ts->date==2020-09-02|>,  [c, d])
    verifyInclude(recs, Str<|ts->date <= 2020-09-02|>,  [a, b, c, d])
    verifyInclude(recs, Str<|ts->date >= 2020-09-02|>,  [c, d, e])
    verifyInclude(recs, Str<|ts->date->foo >= 2020-09-02|>,  [,])

    // time
    verifyInclude(recs, Str<|ts->time == 02:00|>,  [b, e])
    verifyInclude(recs, Str<|ts->time <= 03:00|>,  [a, b, c, e])
    verifyInclude(recs, Str<|ts->time > 03:00|>,  [d])

    // tz
    verifyInclude(recs, Str<|ts->tz == "New_York"|>,  [a, b, c, d, e])
    verifyInclude(recs, Str<|ts->tz == "Chicago"|>,  [,])

  }

  Void verifyInclude(Dict[] recs, Str filter, Dict[] expected)
  {
    f := Filter(filter)
    pather := |Ref r->Dict?| { recs.find |x| { x->dis == r.id } }
    actual := recs.findAll |r| { f.matches(r, PatherContext(pather)) }

    verifyEq(actual.size, expected.size)
    actual.each |r, i| { verifySame(r, expected[i]) }

    // test out null pather
    noPath := recs.findAll |r| { f.matches(r, HaystackContext.nil) }
    if (filter.contains("->") && !filter.startsWith("ts->"))
      verifyEq(noPath.size, filter.contains("thru") ? 1 : 0)
    else
      verifyEq(noPath, actual)
  }

//////////////////////////////////////////////////////////////////////////
// Search
//////////////////////////////////////////////////////////////////////////

  Void testSearch()
  {
    id := Ref.gen
    d := ["id": Ref("abcdefgh-12345678", "Foo Bar"), "siteRef":Ref("efa3", "UVa"),
          "xyz":m, "geoCity":"Richmond"]

    // id.id
    verifySearch(d, "abcdefgh", true)
    verifySearch(d, "abcdefghx", false)
    verifySearch(d, "12345678", true)
    verifySearch(d, "12345678x", false)

    // id.dis
    verifySearch(d, "foo", true)
    verifySearch(d, "FOO", true)
    verifySearch(d, "bar", true)
    verifySearch(d, "baz", false)
    verifySearch(d, "re:Foo.*", true)
    verifySearch(d, "re:F...B..", true)
    verifySearch(d, "re:F...X..", false)

    // f:
    verifySearch(d, "f:geoCity", true)
    verifySearch(d, "f:geoCity==\"Boston\"", false)
    verifySearch(d, "f:geoCity==\"Richmond\"", true)
    verifySearch(d, "f:xyz", true)
    verifySearch(d, "f:not xyz", false)
   }

  Void verifySearch(Str:Obj tags, Str pattern, Bool expected)
  {
    s := Filter.search(pattern)
    verifyEq(s.type, FilterType.search)
    d := Etc.makeDict(tags)
    actual := s.matches(d, HaystackContext.nil)
    // echo("$s [$s.typeof] $d   >>> $actual ?= $expected")
    verifyEq(actual, expected)
  }

}

