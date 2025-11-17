//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Feb 2025  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetom
using haystack
using axon
using hx

**
** FuncTest
**
@Js
class FuncTest : AbstractXetoTest
{
  Void testBasics()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestBasics(ns) }
  }

  private Void doTestBasics(Namespace ns)
  {
    lib := ns.lib("hx.test.xeto")

    // non-func
    num := ns.spec("sys::Number")
    verifyEq(num.isGlobal, false)
    verifyEq(num.isType, true)
    verifyEq(num.isFunc, false)
    verifyErr(UnsupportedErr#) { num.func }

    // ping1
    f := lib.spec("ping1")
    verifyFunc(ns, f, [,], "sys::Date")
    TestAxonContext(ns).asCur |cx|
    {
      verifyEq(f.func.thunk.callList, Date.today)
    }

    // ping2 (missing facet)
    f = lib.spec("ping2")
    verifyFunc(ns, f, [,], "sys::Date")
    TestAxonContext(ns).asCur |cx|
    {
      msg := "Method missing @Api facet: testXeto::XetoFuncs.ping2"
      verifyErrMsg(Err#, msg) { f.func.thunk.callList }
    }

    // add
    verifyAdd(ns, lib.spec("add1"), true)  // Axon
    verifyAdd(ns, lib.spec("add2"), true)  // Fantom
    verifyAdd(ns, lib.spec("add3"), false) // not allowed
    if (!ns.env.isRemote) verifyAdd(ns, lib.spec("add4"), true) // Xeto component graph
  }

  private Void verifyAdd(Namespace ns, Spec f, Bool valid)
  {
    num := ns.spec("sys::Number")

    verifyFunc(ns, f, ["a: sys::Number", "b: sys::Number"], "sys::Number")

    if (!valid)
    {
      verifyErr(Err#) { f.func.thunk }
      return
    }

    a := (TopFn)f.func.thunk
    verifyEq(a.params.size, 2)
    verifyEq(a.params[0].name, "a")
    verifyEq(a.params[1].name, "b")
    TestAxonContext(ns).asCur |cx|
    {
      // Thunk.callList
      verifyEq(a.callList([n(4), n(5)]), n(9))

      // Fn.call
      verifyEq(a.call(cx, [n(3), n(5)]), n(8))
    }
  }

  Void verifyFunc(Namespace ns, Spec f, Str[] params, Str ret)
  {
    verifyEq(f.isFunc,   true)
    verifyEq(f.isType,   false)
    verifyEq(f.isGlobal, false)

    verifySame(f.lib.func(f.name), f)
    verifySame(f.lib.type(f.name, false), null)
    verifySame(f.lib.global(f.name, false), null)

    verifyEq(f.func.arity, params.size)
    verifyEq(f.func.params.size, params.size)
    f.func.params.each |p, i|
    {
      verifyEq("$p.name: $p.type", params[i])
      verifySame(p.type, ns.spec(p.type.qname))
    }
    verifyEq(f.func.returns.type.qname, ret)
  }

//////////////////////////////////////////////////////////////////////////
// Test Cache
//////////////////////////////////////////////////////////////////////////

  Void testCache()
  {
    ns := createNamespace(["axon"])

    now := ns.unqualifiedFunc("now")
    list := ns.unqualifiedFuncs("now")
    verifyEq(list, Spec[now])
    verifySame(list.first, now)
    verifySame(list, ns.unqualifiedFuncs("now"))
    verifySame(list, ns.unqualifiedFuncs("now"))
  }
}

**************************************************************************
** XetoFuncs
**************************************************************************

@Js
class XetoFuncs
{
  // avail
  @Api static Date ping1() { Date.today }

  // not available
  static Date ping2() { Date.today }

  @Api static Number add2(Number a, Number b) { a + b }

  // not available
  static Number add3(Number a, Number b) { a + b }
}

**************************************************************************
** TestAxonContext
**************************************************************************

@Js
class TestAxonContext : AxonContext
{

  Void asCur(|This| f)
  {
    Actor.locals[actorLocalsKey] = this
    f(this)
    Actor.locals.remove(actorLocalsKey)
  }

  new make(Namespace ns) { this.ns = ns }

//////////////////////////////////////////////////////////////////////////
// XetoContext
//////////////////////////////////////////////////////////////////////////

  override xeto::Dict? xetoReadById(Obj id) { throw unsupported }

  override Obj? xetoReadAllEachWhile(Str filter, |xeto::Dict->Obj?| f) { throw unsupported }

//////////////////////////////////////////////////////////////////////////
// CompContext
//////////////////////////////////////////////////////////////////////////

  override DateTime now := DateTime.now

//////////////////////////////////////////////////////////////////////////
// HaystackContext
//////////////////////////////////////////////////////////////////////////

  override Dict? deref(Ref id) { throw unsupported }

  override once FilterInference inference() { throw unsupported }

  override Dict toDict() { Etc.dict0 }

//////////////////////////////////////////////////////////////////////////
// AxonContext
//////////////////////////////////////////////////////////////////////////

  override DefNamespace defs() { throw unsupported }

  override Namespace ns

  Err unsupported() { UnsupportedErr("TestAxonContext") }
}

