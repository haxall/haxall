//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using axon
using hx

**
** SwitchTest tests switch pattern matching
**
class SwitchTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Literals
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testLiterals()
  {
    src :=
      Str<|switch (x)
             case 200 => "ok"
             case 404 => "not found"
             case "foo" => "str"
             case -1 => "neg"
             case true => "true"
             case null => "null"
             case 2026-10-30 => "date"
             case @abc => "ref"
             default => "other"
           end|>
    verifySwitch(src, "200", "ok")
    verifySwitch(src, "404", "not found")
    verifySwitch(src, "\"foo\"", "str")
    verifySwitch(src, "\"bar\"", "other")
    verifySwitch(src, "-1", "neg")
    verifySwitch(src, "true", "true")
    verifySwitch(src, "false", "other")
    verifySwitch(src, "null", "null")
    verifySwitch(src, "2026-10-30", "date")
    verifySwitch(src, "@abc", "ref")
    verifySwitch(src, "500", "other")

    // first match wins
    verifySwitch("switch (x) case 1 => \"a\"; case 1 => \"b\" end", "1", "a")

    // Axon equality: unitless literal matches any unit
    verifySwitch("switch (x) case 72 => 1 default => 2 end", "72°F", n(1))
    verifySwitch("switch (x) case 72°C => 1 default => 2 end", "72°F", n(2))
    verifySwitch("switch (x) case 72°F => 1 default => 2 end", "72", n(1))
  }

//////////////////////////////////////////////////////////////////////////
// Or
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testOr()
  {
    src :=
      Str<|switch (x)
             case 200 or 204 => "ok"
             case "a" or "b" or "c" => "abc"
             case null or false => "falsy"
             case 1 or 5..9 => "one or five to nine"
             default => "other"
           end|>
    verifySwitch(src, "200", "ok")
    verifySwitch(src, "204", "ok")
    verifySwitch(src, "201", "other")
    verifySwitch(src, "\"b\"", "abc")
    verifySwitch(src, "\"c\"", "abc")
    verifySwitch(src, "null", "falsy")
    verifySwitch(src, "false", "falsy")
    verifySwitch(src, "1", "one or five to nine")
    verifySwitch(src, "7", "one or five to nine")
    verifySwitch(src, "3", "other")
  }

//////////////////////////////////////////////////////////////////////////
// Ranges
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testRanges()
  {
    src :=
      Str<|switch (x)
             case 200..299 => "success"
             case 400..499 => "client err"
             case "a".."m" => "a-m"
             default => "other"
           end|>
    verifySwitch(src, "200", "success")
    verifySwitch(src, "250", "success")
    verifySwitch(src, "299", "success")
    verifySwitch(src, "300", "other")
    verifySwitch(src, "404", "client err")
    verifySwitch(src, "-5", "other")
    verifySwitch(src, "\"foo\"", "a-m")
    verifySwitch(src, "\"zed\"", "other")

    // different type than bounds does not match or throw
    verifySwitch(src, "2026-10-30", "other")
    verifySwitch(src, "null", "other")

    // date ranges and month literals match single dates
    src =
      Str<|switch (x)
             case 2026-10-01..2026-10-15 => "early oct"
             case 2026-10 => "late oct"
             case 2026-11 or 2026-12 => "nov or dec"
             default => "other"
           end|>
    verifySwitch(src, "2026-10-01", "early oct")
    verifySwitch(src, "2026-10-15", "early oct")
    verifySwitch(src, "2026-10-16", "late oct")
    verifySwitch(src, "2026-10-31", "late oct")
    verifySwitch(src, "2026-11-11", "nov or dec")
    verifySwitch(src, "2026-12-31", "nov or dec")
    verifySwitch(src, "2027-01-01", "other")
    verifySwitch(src, "\"2026-10-20\"", "other")

    // month literal still equals same month span
    verifySwitch("switch (x) case 2026-10 => 1 end", "2026-10", n(1))
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testSpecs()
  {
    addLib("ph")
    site  := addRec(["dis":"Site", "spec":Ref("ph::Site"), "site":m])
    ahu   := addRec(["dis":"AHU", "spec":Ref("ph::Ahu"), "equip":m, "ahu":m, "siteRef":site.id])
    vav   := addRec(["dis":"VAV", "spec":Ref("ph::Vav"), "equip":m, "vav":m, "siteRef":site.id])
    untyped := addRec(["dis":"No spec", "site":m])

    f :=
      Str<|(x) => switch (x)
             case Ahu => "ahu"
             case ph::Equip => "equip"
             case Site => "site"
             case Number => "number"
             case Str or Date => "str or date"
             case Dict => "dict"
             default => "other"
           end|>
    verifyCall(f, ahu, "ahu")
    verifyCall(f, vav, "equip")
    verifyCall(f, site, "site")
    verifyCall(f, n(3), "number")
    verifyCall(f, n(3, "kW"), "number")
    verifyCall(f, "x", "str or date")
    verifyCall(f, Date.today, "str or date")
    verifyCall(f, Marker.val, "other")
    verifyCall(f, null, "other")

    // nominal: dict must declare spec tag
    verifyCall(f, untyped, "dict")
    verifyCall(f, Etc.dict1("site", Marker.val), "dict")

    // spec or null at top level, either order
    verifyCall(Str<|(x) => switch (x) case Ahu or null => "ahu or null" default => "other" end|>, ahu, "ahu or null")
    verifyCall(Str<|(x) => switch (x) case Ahu or null => "ahu or null" default => "other" end|>, null, "ahu or null")
    verifyCall(Str<|(x) => switch (x) case Ahu or null => "ahu or null" default => "other" end|>, site, "other")
    verifyCall(Str<|(x) => switch (x) case null or Ahu => "null or ahu" default => "other" end|>, null, "null or ahu")
    verifyCall(Str<|(x) => switch (x) case null or Ahu => "null or ahu" default => "other" end|>, ahu, "null or ahu")

    // specs mix with literals
    verifyCall(Str<|(x) => switch (x) case 0 or Str => "zero or str" default => "other" end|>, n(0), "zero or str")
    verifyCall(Str<|(x) => switch (x) case 0 or Str => "zero or str" default => "other" end|>, n(1), "other")

    // unknown spec raises error when matched
    verifyErr(UnknownTypeErr#) { eval("switch (1) case BadSpecName => 1 end") }

    // lowercase name is not a spec
    verifyErr(SyntaxErr#) { eval("switch (1) case ph => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case ph:: => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case ph::site => 1 end") }
  }

//////////////////////////////////////////////////////////////////////////
// Enums
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testEnums()
  {
    addLib("ph")

    // Str keys
    f :=
      Str<|(x) => switch (x)
             case CurStatus.ok => "ok"
             case ph::CurStatus.fault or CurStatus.down => "bad"
             case CurStatus => "other status"
             default => "not status"
           end|>
    verifyCall(f, "ok", "ok")
    verifyCall(f, "fault", "bad")
    verifyCall(f, "down", "bad")
    verifyCall(f, "stale", "other status")
    verifyCall(f, "bogus", "not status")
    verifyCall(f, n(3), "not status")
    verifyCall(f, null, "not status")

    // Str key or bound Fantom enum
    f =
      Str<|(x) => switch (x)
             case SpanMode.today => "today"
             case SpanMode => "span mode"
             default => "other"
           end|>
    verifyCall(f, "today", "today")
    verifyCall(f, SpanMode.today, "today")
    verifyCall(f, "lastWeek", "span mode")
    verifyCall(f, SpanMode.lastWeek, "span mode")
    verifyCall(f, "bogus", "other")

    // item key differs from item name
    f = Str<|(x) => switch (x) case TimeZone.utc => "utc" default => "other" end|>
    verifyCall(f, "UTC", "utc")
    verifyCall(f, TimeZone.utc, "utc")
    verifyCall(f, "utc", "other")

    // unknown item or not enum
    verifyErr(EvalErr#) { eval("switch (\"ok\") case CurStatus.bogus => 1 end") }
    verifyErr(EvalErr#) { eval("switch (\"ok\") case Str.bogus => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch (\"ok\") case CurStatus. => 1 end") }
  }

//////////////////////////////////////////////////////////////////////////
// Dicts
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testDicts()
  {
    addLib("ph")
    site := addRec(["dis":"Site", "spec":Ref("ph::Site"), "site":m, "area":n(9000, "ft²")])
    ahu  := addRec(["dis":"AHU", "spec":Ref("ph::Ahu"), "equip":m, "ahu":m, "siteRef":site.id])
    vav  := addRec(["dis":"VAV", "spec":Ref("ph::Vav"), "equip":m, "vav":m, "siteRef":site.id, "airRef":ahu.id])
    pt   := Etc.makeDict(["dis":"Temp", "point":m, "kind":"Number", "unit":"°F", "curStatus":"fault"])

    f :=
      Str<|(x) => switch (x)
             case Vav {airRef} => "vav with airRef"
             case Ahu {siteRef: Ref} => "ahu with siteRef"
             case {site, area: 1..1000} => "small site"
             case {site, area: Number} => "site with area"
             case {point, curStatus: CurStatus.fault or CurStatus.down} => "bad point"
             case {kind: "Number", unit: "°F"} => "fahrenheit"
             case {foo} or {bar} => "foo or bar"
             case {} => "dict"
             default => "other"
           end|>
    verifyCall(f, vav, "vav with airRef")
    verifyCall(f, ahu, "ahu with siteRef")
    verifyCall(f, site, "site with area")
    verifyCall(f, Etc.dict2("site", m, "area", n(500, "ft²")), "small site")
    verifyCall(f, pt, "bad point")
    verifyCall(f, Etc.dictx("point", m, "kind", "Number", "unit", "°F", "curStatus", "ok"), "fahrenheit")
    verifyCall(f, Etc.dict1("foo", m), "foo or bar")
    verifyCall(f, Etc.dict1("bar", n(3)), "foo or bar")
    verifyCall(f, Etc.dict0, "dict")
    verifyCall(f, n(3), "other")
    verifyCall(f, null, "other")

    // spec + dict requires both
    verifyCall(Str<|(x) => switch (x) case Vav {airRef} => 1 default => 2 end|>, Etc.dict2("vav", m, "airRef", ahu.id), n(2))
    verifyCall(Str<|(x) => switch (x) case Vav {foo} => 1 default => 2 end|>, vav, n(2))

    // missing tag and constraint failure
    verifyCall(Str<|(x) => switch (x) case {area: Number} => 1 default => 2 end|>, Etc.dict1("area", "big"), n(2))
    verifyCall(Str<|(x) => switch (x) case {area: Number} => 1 default => 2 end|>, Etc.dict1("site", m), n(2))

    // optional slot pattern matches missing tag
    f = Str<|(x) => switch (x) case {area: Number?} => "opt" default => "other" end|>
    verifyCall(f, Etc.dict1("area", n(3)), "opt")
    verifyCall(f, Etc.dict1("site", m), "opt")
    verifyCall(f, Etc.dict1("area", "big"), "other")
    f = Str<|(x) => switch (x) case {area: Str or Number?} => 1 default => 2 end|>
    verifyCall(f, Etc.dict0, n(1))
    verifyCall(f, Etc.dict1("area", "big"), n(1))
    verifyCall(f, Etc.dict1("area", n(3)), n(1))
    verifyCall(f, Etc.dict1("area", m), n(2))

    // null literal in slot never matches missing tag, only ? does
    verifyCall(Str<|(x) => switch (x) case {equip: null} => 1 default => 2 end|>, Etc.dict0, n(2))
    f = Str<|(x) => switch (x) case {area: Number or null} => "num" default => "other" end|>
    verifyCall(f, Etc.dict1("area", n(3)), "num")
    verifyCall(f, Etc.dict0, "other")
    verifyCall(f, Etc.dict1("area", "big"), "other")

    // optional only allowed in slots
    verifyErr(SyntaxErr#) { eval("switch (1) case Number? => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 or Str? => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case {a}? => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case {a?} => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case {a: Str? or Number} => 1 end") }

    // keyword and quoted tag names
    verifyCall(Str<|(x) => switch (x) case {for, "not tag": 3} => 1 default => 2 end|>, Etc.dict2("for", m, "not tag", n(3)), n(1))

    // nested dict patterns are not supported
    verifyErr(SyntaxErr#) { eval("switch ({}) case {a: {b}} => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch ({}) case {a: 1 or {b}} => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch ({}) case {a: Site {b}} => 1 end") }
    verifyErr(SyntaxErr#) { eval("switch ({}) case {a b} => 1 end") }
  }

//////////////////////////////////////////////////////////////////////////
// Default
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testDefault()
  {
    // no match without default evaluates to null like if without else
    verifySwitch("switch (x) case 4 => 5 end", "3", null)
    verifySwitch("switch (x) end", "3", null)

    // only default
    verifySwitch("switch (x) default => 7 end", "3", n(7))

    // subject evaluated once
    verifyEval(Str<|do
                      n: 0
                      switch (do n = n + 1; n end)
                        case 2 => "two"
                        case 1 => "one"
                      end
                      n
                    end|>, n(1))
  }

//////////////////////////////////////////////////////////////////////////
// Bodies
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testBodies()
  {
    // do block bodies
    verifyEval(Str<|switch (2)
                      case 1 => do
                        a: 10
                        a + 1
                      end
                      case 2 => do
                        b: 20
                        b + 2
                      end
                    end|>, n(22))

    // switch is an expr; like if it must be grouped inside an operator
    verifyEval(Str<|"x" + (switch (1) case 1 => "y" end) + "z"|>, "xyz")
    verifyEval(Str<|[switch (1) case 1 => "y" end, 2]|>, Obj?["y", n(2)])

    // return in body exits enclosing func
    f := Str<|(x) => do
                switch (x)
                  case 1 => return "early"
                end
                "late"
              end|>
    verifyCall(f, n(1), "early")
    verifyCall(f, n(2), "late")

    // body can assign outer var
    verifyEval(Str<|do
                      t: 0
                      switch (3) case 3 => t = 9 end
                      t
                    end|>, n(9))

    // nested switch
    verifyEval(Str<|switch (1)
                      case 1 => switch (2)
                        case 2 => "inner"
                      end
                    end|>, "inner")
  }

//////////////////////////////////////////////////////////////////////////
// Errors
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testErrors()
  {
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 => 2") }
    verifyErr(SyntaxErr#) { eval("switch (1) case foo => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 + 2 => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) default => 1 case 2 => 3 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) default => 1 default => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch 1 case 1 => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 or => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case 1..\"x\" => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case null..3 => 2 end") }
  }

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  @HxTestProj
  Void testAst()
  {
    src :=
      Str<|switch (x)
             case 200 => 1
             case "a" or 4 => 2
             case 400..499 => 3
             case 2026-10 => 4
             case ph::Site or Number => 5
             case CurStatus.ok => 6
             case Vav {airRef, kind: "Number" or Str, "not tag", area: Number?} => 7
             default => 8
           end|>
    expr := Parser(src.in).parse

    // print round trips
    str := expr.toStr
    verifyEq(Parser(str.in).parse.toStr, str)

    // encode
    ast := expr.encode
    verifyEq(ast->type, "switch")
    Dict[] cases := ast->cases
    verifyEq(cases.map |c->Obj?| { c->pattern->type }, Obj?["literalPattern", "orPattern", "rangePattern", "literalPattern", "orPattern", "enumPattern", "dictPattern"])
    Dict dp := cases[6]->pattern
    verifyEq(dp->spec->spec->topName, "Vav")
    verifyEq(((Dict[])dp->slots).map |x->Obj?| { x->name }, Obj?["airRef", "kind", "not tag", "area"])
    verifyEq(((Dict[])dp->slots)[3]->pattern->type, "specPattern")
    verifyEq(((Dict[])dp->slots)[3]->optional, true)
    verifyEq(((Dict[])dp->slots)[1]->optional, false)
    verifyEq(((Dict[])dp->slots)[1]->pattern->type, "orPattern")
    verifyEq(cases[5]->pattern->spec->topName, "CurStatus")
    verifyEq(cases[5]->pattern->item, "ok")
    verifyEq(((Dict[])cases[4]->pattern->alts).map |p->Obj?| { p->type }, Obj?["specPattern", "specPattern"])
    verifyEq(((Dict[])cases[4]->pattern->alts).map |p->Obj?| { p->spec->topName }, Obj?["ph::Site", "Number"])
    verifyEq(cases[0]->pattern->val, n(200))
    verifyEq(((Dict[])cases[1]->pattern->alts).map |p->Obj?| { p->val }, Obj?["a", n(4)])
    verifyEq(cases[2]->pattern->start, n(400))
    verifyEq(cases[2]->pattern->end, n(499))
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Eval switch src with variable x bound to subject src
  Void verifySwitch(Str src, Str subject, Obj? expected)
  {
    verifyEval("do x: $subject\n$src\nend", expected)
  }

  ** Verify src prints and reparses to same source, then eval
  Void verifyEval(Str src, Obj? expected)
  {
    cx := makeContext
    str := cx.parse(src).toStr
    verifyEq(cx.parse(str).toStr, str)
    verifyEq(cx.eval(str), expected)
  }

  ** Call func src with one arg
  Void verifyCall(Str fn, Obj? arg, Obj? expected)
  {
    cx := makeContext
    verifyEq(cx.evalToFunc(fn).call(cx, [arg]), expected)
  }
}
