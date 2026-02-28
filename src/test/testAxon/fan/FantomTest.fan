//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using concurrent
using xeto
using xetom
using haystack
using axon

**
** FantomTest
**
@Js
class FantomTest : HaystackTest
{
  CompSpace? cs
  Comp? comp

  override Void setup()
  {
    super.setup
    ns := XetoEnv.cur.createNamespaceFromNames(["sys.comp"])
    cs = CompSpace(ns).initRoot { TestComp() }
    Actor.locals[CompSpace.actorKey] = cs
    comp = TestComp()
  }

  override Void teardown()
  {
    super.teardown
    Actor.locals.remove(CompSpace.actorKey)
  }

  Void test()
  {
    // global axon functions
    verifyEval(Str<|today()|>, Date.today)
    verifyEval(Str<|format(Date.today, "D-MMM-YY")|>, Date.today.toLocale("D-MMM-YY"))

    // static Fantom methods
    verifyEval(Str<|Date.today|>, Date.today)
    verifyEval(Str<|sys::Date.today|>, Date.today)
    verifyEval(Str<|Date.fromStr("2024-04-21")|>, Date("2024-04-21"))
    verifyEval(Str<|sys::Date.fromStr("2024-04-21")|>, Date("2024-04-21"))

    // static Fantom fields
    verifyEval(Str<|FantomEx.sx|>, "static field")
    verifyEval(Str<|testAxon::FantomEx.sx|>, "static field")

    // instance Fantom method
    verifyEval(Str<|FantomEx.make.bar|>, "bar!")
    verifyEval(Str<|FantomEx.make.add1(4, 5)|>, n(9))
    verifyEval(Str<|FantomEx().bar|>, "bar!")

    // instance fields
    verifyEval(Str<|FantomEx.make.foo|>, "foo!")
    verifyEval(Str<|do x: FantomEx(); x.foo = "set!"; x.foo; end|>, "set!")

    // coercion out of Fantom
    verifyEval(Str<|Float.posInf|>, Number.posInf)
    verifyEval(Str<|Int.fromStr("3")|>, n(3))
    verifyEval(Str<|Float.fromStr("3")|>, n(3))
    verifyEval(Str<|Duration.fromStr("3min")|>, n(3, "min"))

    // coercion into Fantom
    verifyEval(Str<|Int.fromStr("abc", 16)|>, n(0xabc))
    verifyEval(Str<|FantomEx.add2(3, 5)|>, n(8))
    verifyEval(Str<|FantomEx.add3(3sec, 5sec)|>, n(8, "sec"))
    verifyEval(Str<|FantomEx.filter1(Point)|>, Filter("Point"))
    verifyEval(Str<|FantomEx.filter1(foo==3)|>, Filter("foo==3"))
    verifyEval(Str<|FantomEx.filter1(FooBar and mark and foo==3)|>, Filter("FooBar and mark and foo==3"))

    // functions
    verifyEval(Str<|FantomEx.fn0(()=>123)|>, n(123))
    verifyEval(Str<|FantomEx.fn1([1, 2, 3]) x => x + 100|>, Obj?[n(101), n(102), n(103)])
    verifyEval(Str<|FantomEx.fn2((a,b)=>[a, b])|>, Obj?["a", "b"])
    verifyEval(Str<|FantomEx.fn3((a,b,c)=>[a, b, c])|>, Obj?["a", "b", "c"])
    verifyEval(Str<|FantomEx.fn4((a,b,c,d)=>[a, b, c, d])|>, Obj?["a", "b", "c", "d"])
    verifyEval(Str<|FantomEx.fn5((a,b,c,d,e)=>[a, b, c, d, e])|>, Obj?["a", "b", "c", "d", "e"])
    verifyEval(Str<|FantomEx.fn6((a,b,c,d,e,f)=>[a, b, c, d, e, f])|>, Obj?["a", "b", "c", "d", "e", "f"])

    // components
    verifyEval(Str<|comp.spec|>, cs.ns.spec("sys.comp::Comp"))
    verifyEval(Str<|comp.a|>, null)
    verifyEval(Str<|comp.a = "1st"|>, "1st")
    verifyEval(Str<|comp.dump|>, null)
    verifyEval(Str<|comp.a|>, "1st")
    verifyEval(Str<|comp.x|>, null)
    verifyEval(Str<|comp.x = "2nd"|>, "2nd")
    verifyEval(Str<|comp.x|>, "2nd")

    // errors
    verifyErrMsg(UnknownTypeErr#, "Bad") { eval("Bad.foo") }
    verifyErrMsg(UnknownTypeErr#, "sys::Bad") { eval("sys::Bad.foo") }
    verifyErrMsg(UnknownTypeErr#, "util::Console") { eval("util::Console.cur") }
    verifyErrMsg(UnknownSlotErr#, "Unknown slot: testAxon::FantomEx.bad") { eval("FantomEx.make.bad") }
  }

  Void verifyEval(Str expr, Obj? expect)
  {
    actual := eval(expr)
    //echo("-- $expr | $actual ?= $expect")
    verifyEq(actual, expect)
  }

  Obj? eval(Str expr)
  {
    cx := FantomTestContext(this)
    cx.defOrAssign("comp", comp, Loc("test"))
    return cx.eval(expr)
  }

}

**************************************************************************
** FantomEx
**************************************************************************

@Js
class FantomEx
{
  Str foo  := "foo!"
  Str bar() { "bar!" }
  Number add1(Number a, Number b) { a + b }
  static Float add2(Int a, Float b) { b + a }
  static Duration add3(Duration a, Duration b) { b + a }
  static const Str sx := "static field"

  static Filter filter1(Filter x) { x }

  static Obj? fn0(|->Obj?| f) { f() }
  static Number[] fn1(Number[] list, |Number->Number| f) { list.map(f) }
  static Obj[] fn2(|Obj? a, Obj? b->Obj| f) { f("a", "b") }
  static Obj[] fn3(|Obj? a, Obj? b, Obj? c->Obj| f) { f("a", "b", "c") }
  static Obj[] fn4(|Obj? a, Obj? b, Obj? c, Obj? d->Obj| f) { f("a", "b", "c", "d") }
  static Obj[] fn5(|Obj? a, Obj? b, Obj? c, Obj? d, Obj? e->Obj| f) { f("a", "b", "c", "d", "e") }
  static Obj[] fn6(|Obj? a, Obj? b, Obj? c, Obj? d, Obj? e, Obj? f->Obj| f) { f("a", "b", "c", "d", "e", "f") }
}

**************************************************************************
** FantomTestContext
**************************************************************************

@Js
internal class FantomTestContext : TestContext
{
  new make(HaystackTest test) : super(test)
  {
    pods := "sys,testAxon".split(',').map |p->Pod| { Pod.find(p) }
    this.ffi = FantomAxonFFI(pods)
  }

  override AxonFFI? ffi
}

**************************************************************************
** TestComp
**************************************************************************

@Js
internal class TestComp : CompObj
{
  Str? a
  {
    get { get("a") }
    set { set("a", it); echo("set a $it") }
  }
}

