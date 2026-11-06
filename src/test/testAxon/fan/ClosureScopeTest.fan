//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Aug 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon

**
** ClosureScopeTest verifies closure variable scoping semantics for both
** eager calls on the live stack and lazy calls of stored closures after
** the lexical scope frames have popped.
**
@Js
class ClosureScopeTest : AxonTest
{

  ** Eager closures run on the live stack: locals are fresh per
  ** call and assignments write-thru to the enclosing scope
  Void testEager()
  {
    cx := ClosureTestContext(this)
    verifyEq(cx.eval(
      """do
           acc: 0
           [1, 2, 3].each(x => do delta: x * 10; acc = acc + delta end)
           acc
         end"""), n(60))

    // local def may shadow enclosing scope var
    verifyEq(cx.eval(
      """do
           v: 100
           r: [1, 2].map(x => do v: x; v end)
           [r, v]
         end"""), Obj?[Obj?[n(1), n(2)], n(100)])
  }

  ** Each call sees only its own lexical scope, never the
  ** variables of an older recursive call of the same func
  Void testRecursion()
  {
    cx := ClosureTestContext(this)
    verifyErr(null) { cx.eval("do f: (n) => if (n == 0) y else do y: n; f(n-1) end; f(3) end") }

    // closures see the locals of their own enclosing call
    verifyEq(cx.eval(
      """do
           g: (n) => do
             y: n * 10
             if (n == 0) [y] else g(n-1).add([1].map(x => y + x).first)
           end
           g(2)
         end"""), Obj?[n(0), n(11), n(21)])
  }

  ** Closures resolve names in the scope they were evaluated in,
  ** never in whatever frames are on the stack when called
  Void testFunarg()
  {
    cx := ClosureTestContext(this)
    verifyEq(cx.eval("do f: (n, g) => do x: n; if (n == 0) return g(); f(n-1, () => x) end; f(2, null) end"), n(1))
    verifyEq(cx.eval("do f: (n, g) => do if (n == 0) return g(); x: n; f(n-1, () => x) end; f(2, null) end"), n(1))

    // closure returned from its func and called after it pops
    verifyEq(cx.eval("do adder: (a) => (b) => a + b; add3: adder(3); add3(4) end"), n(7))

    // local funcs may call each other before they are defined
    verifyEq(cx.eval("(() => do a: (n) => b(n); b: (n) => n * 2; a(5) end)()"), n(10))

    // switch case binds are seen by closures in the arm
    verifyEq(cx.eval("do f: switch ({a: 5}) case {a as v} => () => v end; f() end"), n(5))

    // closure called inside a switch arm does not see the caller's locals
    verifyErr(null) { cx.eval("do f: () => secret; g: () => do secret: 5; switch (1) case 1 => f() end end; g() end") }
  }

  ** Closures are not immutable; toConst snapshots captured variables
  ** into an immutable func that may be stored in dicts and grids
  Void testToConst()
  {
    cx := ClosureTestContext(this)

    // closures cannot be stored in dicts
    verifyEq(cx.eval("x => x + 1").typeof, Closure#)
    verifyErr(EvalErr#) { cx.eval("{f: x => x + 1}") }
    verifyErr(EvalErr#) { cx.eval("{f: [1, [x => x + 1]]}") }

    // no captures
    verifyEq(cx.eval("toConst(x => x + 1)").isImmutable, true)
    verifyEq(cx.eval(Str<|do d: {stage: toConst((groups) => groups[1].parseNumber)}; fn: d->stage; fn(["x", "3"]) end|>), n(3))
    verifyEq(cx.eval("do g: [{f: toConst(x => x.abs)}].toGrid; fn: g.first->f; fn(-4) end"), n(4))
    verifyEq(cx.eval("do d: {fs: [toConst(x => x + 1)]}; fn: d->fs.first; fn(2) end"), n(3))

    // top-level funcs are already const
    verifyEq(cx.eval("do f: toConst(abs); f(-2) end"), n(2))

    // captured values are snapshotted
    verifyEq(cx.eval("do limit: 10; f: toConst(x => x > limit); limit = 0; f(5) end"), false)
    verifyEq(cx.eval("do names: [\"a\", \"b\"]; f: toConst(x => names.contains(x)); [f(\"a\"), f(\"c\")] end"), Obj?[true, false])
    verifyEq(cx.eval("do y: null; f: toConst(() => y); f() end"), null)

    // captured vars cannot be assigned, but locals can
    verifyErrMsg(EvalErr#, "Cannot assign captured var 'acc' in const func") { cx.eval("do acc: 0; f: toConst(x => do acc = acc + x; acc end); f(1) end") }
    verifyEq(cx.eval("do f: toConst(x => do acc: 0; acc = acc + x; acc end); [f(1), f(2)] end"), Obj?[n(1), n(2)])

    // const funcs escape their scope
    verifyEq(cx.eval("do adder: (a) => toConst((b) => a + b); {add3: adder(3)}->add3(4) end"), n(7))

    // vars that cannot be immutable raise error if used, even if they
    // shadow a top-level func, but are not visible to filter vars
    verifyErrMsg(EvalErr#, "Var 'g' is not immutable and cannot be used in const func") { cx.eval("do g: x => x; f: toConst(y => g(y)); f(4) end") }
    verifyErrMsg(EvalErr#, "Var 'size' is not immutable and cannot be used in const func") { cx.eval("do size: x => 99; f: toConst(y => size(y)); f([1, 2]) end") }
    verifyEq(cx.eval("do g: x => x; f: toConst(() => [{g}, {}].findAll(filterToFunc(g)).size); f() end"), n(1))

    // errors report the Axon location of the use
    EvalErr? err
    try cx.eval("do\n  g: x => x\n  f: toConst(y =>\n    g(y))\n  f(4)\nend")
    catch (EvalErr e) err = e
    verifyEq(err.loc.line, 4)
    verifyEq(cx.eval("do g: x => x; f: toConst(y => y * 3); f(4) end"), n(12))
    verifyEq(cx.eval("do g: toConst(x => x * 2); f: toConst(y => g(y)); f(4) end"), n(8))
  }

  ** Lazy calls while lexical frames still live: locals fresh per
  ** call, accumulator persists, write-thru to enclosing scope
  Void testLazyInScope()
  {
    cx := ClosureTestContext(this)
    verifyEq(cx.eval(
      """do
           lastVal: 10
           testCapture(x => do
             newVal: x
             change: newVal - lastVal
             lastVal = newVal
             change
           end)
           r1: testInvoke(0, 15)
           r2: testInvoke(0, 25)
           [r1, r2, lastVal]
         end"""), Obj?[n(5), n(10), n(25)])
  }

  ** Assignment writes thru nested closure scopes to the outermost
  ** scope, including scopes whose loop frames have popped
  Void testLazyWriteThruDeep()
  {
    cx := ClosureTestContext(this)
    verifyEq(cx.eval(
      """do
           total: 0
           [1].each(a => [1].each(b => [1].each(c =>
             testCapture(x => do total = total + x + a + b + c; total end))))
           testInvoke(0, 5)
           testInvoke(0, 3)
           total
         end"""), n(14))
  }

  ** Lazy calls after the defining function frame has popped
  Void testLazyEscape()
  {
    cx := ClosureTestContext(this)
    cx.eval(
      """(() => do
           lastVal: 10
           testCapture(x => do
             newVal: x
             change: newVal - lastVal
             lastVal = newVal
             change
           end)
         end)()""")
    verifyEq(cx.lazyCalls[0].call(n(15)), n(5))
    verifyEq(cx.lazyCalls[0].call(n(25)), n(10))
  }

  ** Local def may shadow captured scope var without collision or write-thru
  Void testLazyShadow()
  {
    cx := ClosureTestContext(this)
    verifyEq(cx.eval(
      """do
           v: 100
           testCapture(x => do v: x; v end)
           a: testInvoke(0, 1)
           b: testInvoke(0, 2)
           [a, b, v]
         end"""), Obj?[n(1), n(2), n(100)])
  }

  ** Two closures over the same scope share its variables
  Void testLazyShared()
  {
    cx := ClosureTestContext(this)
    verifyEq(cx.eval(
      """do
           count: 0
           testCapture(x => do count = count + x; count end)
           testCapture(x => do count = count + x; count end)
           a: testInvoke(0, 1)
           b: testInvoke(1, 1)
           [a, b, count]
         end"""), Obj?[n(1), n(2), n(2)])
  }

  ** Capture during a lazy call chains transitively to the defining scope
  Void testLazyNestedCapture()
  {
    cx := ClosureTestContext(this)
    verifyEq(cx.eval(
      """do
           total: 0
           testCapture(x => do
             total = total + x
             testCapture(y => do total = total + y; total end)
             total
           end)
           testInvoke(0, 1)
           testInvoke(1, 10)
           total
         end"""), n(11))
  }
}

**************************************************************************
** ClosureTestContext
**************************************************************************

@Js
internal class ClosureTestContext : TestContext
{
  new make(HaystackTest test) : super(test) {}

  static const Str:Fn funcs := FantomFn.reflectType(ClosureScopeFuncs#)

  ** Lazy invoke funcs registered by testCapture in capture order
  Func[] lazyCalls := [,]

  override Obj? doResolveTop(TopName x, Bool checked := true)
  {
    funcs[x.name] ?: super.doResolveTop(x, checked)
  }
}

**************************************************************************
** ClosureScopeFuncs
**************************************************************************

@Js
internal class ClosureScopeFuncs
{
  ** Store away the closure and register a lazy invoke func the
  ** same way hisKit lazy grids store away their filter closures
  @Axon static Obj? testCapture(Callable fn)
  {
    cx := (ClosureTestContext)AxonContext.curAxon
    args := [null]
    cx.lazyCalls.add |Obj? a->Obj?| { fn.call(cx, args.set(0, a)) }
    return null
  }

  ** Invoke a lazy func registered by testCapture
  @Axon static Obj? testInvoke(Number index, Obj? arg)
  {
    cx := (ClosureTestContext)AxonContext.curAxon
    return cx.lazyCalls[index.toInt].call(arg)
  }
}
