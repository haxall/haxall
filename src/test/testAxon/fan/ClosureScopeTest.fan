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
** eager calls on the live stack and lazy calls via AxonContext.scopeCapture
** and callInScope after the lexical scope frames have popped.
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

  ** Assignment writes thru nested closure frames to the outermost
  ** scope; captured chain mixes popped loop frames with live root
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

  ** Two captures of the same scope share the same live frames
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
  ** Capture closure scope and register a lazy invoke func the
  ** same way hisKit lazy grids store away their filter closures
  @Axon static Obj? testCapture(Fn fn)
  {
    cx := (ClosureTestContext)AxonContext.curAxon
    scope := cx.scopeCapture(fn)
    args := [null]
    cx.lazyCalls.add |Obj? a->Obj?| { cx.callInScope(fn, args.set(0, a), fn.loc, scope) }
    return null
  }

  ** Invoke a lazy func registered by testCapture
  @Axon static Obj? testInvoke(Number index, Obj? arg)
  {
    cx := (ClosureTestContext)AxonContext.curAxon
    return cx.lazyCalls[index.toInt].call(arg)
  }
}
