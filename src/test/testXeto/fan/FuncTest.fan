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
  Void testNamespace()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestNamespace(ns) }
  }

  private Void doTestNamespace(LibNamespace ns)
  {
    lib := ns.lib("hx.test.xeto")

    // non-func
    num := ns.spec("sys::Number")
    verifyEq(num.isGlobal, false)
    verifyEq(num.isType, true)
    verifyEq(num.isFunc, false)
    verifyErr(UnsupportedErr#) { num.func }

    // Axon
    verifyAdd(ns, lib.spec("add1"), true)  // Axon
    verifyAdd(ns, lib.spec("add2"), true)  // Fantom
    verifyAdd(ns, lib.spec("add3"), false) // not allowed
    if (!ns.isRemote) verifyAdd(ns, lib.spec("add4"), true) // Xeto component graph
  }

  private Void verifyAdd(LibNamespace ns, Spec f, Bool canCall)
  {
    num := ns.spec("sys::Number")

echo(">>> verifyAdd $f")

    verifyFunc(ns, f, ["a: sys::Number", "b: sys::Number"], "sys::Number")

    x := f.func.thunk
    /*
    verifySame(f.func.axon, a)
    verifyEq(a.params.size, 2)
    verifyEq(a.params[0].name, "a")
    verifyEq(a.params[1].name, "b")
    TestAxonContext(ns).asCur |cx|
    {
      verifyEq(a.call(cx, [n(3), n(5)]), n(8))
    }
    */
  }

  Void verifyFunc(LibNamespace ns, Spec f, Str[] params, Str ret)
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
}

**************************************************************************
** FuncApiTest
**************************************************************************

**
** FuncApiTest
**
class FuncApiTest : AbstractXetoTest
{
  /* TODO
  Void testNamespace()
  {
    verifyLocalAndRemote(["sys", "hx.test.xeto"]) |ns| { doTestNamespace(ns) }
  }

  private Void doTestNamespace(LibNamespace ns)
  {
    lib := ns.lib("hx.test.xeto")

    // Api - ping1
    f := lib.spec("ping1")
    verifyGlobalFunc(ns, f, [,], "sys::Date")
    verifyEq(f.func.api is Method, true)
    verifyEq(f.func.api->call(null), Date.today)

    // Api - ping2 (missing facet)
    f = lib.spec("ping2")
    verifyGlobalFunc(ns, f, [,], "sys::Date")
    verifyEq(f.func.api(false), null)
    verifyErr(UnsupportedErr#) { f.func.api }
  }
    */
}

**************************************************************************
** TextAxon
**************************************************************************

@Js
class TestAxon
{
  @Axon static Number add2(Number a, Number b) { a + b }

  // not available
  static Number add3(Number a, Number b) { a + b }
}

**************************************************************************
** TextApi
**************************************************************************

class TestApi
{
  @HxApi static Date ping1(HxApiReq? req) { Date.today }

  // not available
  static Date ping2(HxApiReq? req) { Date.today }
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

  new make(LibNamespace ns) { this.ns = ns }

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

  override LibNamespace ns

  override Fn? findTop(Str name, Bool checked := true)
  {
    throw unsupported
  }

  override Dict? trapRef(Ref id, Bool checked := true)
  {
    throw unsupported
  }

  ** Evaluate an expression or if a filter then readAll convenience
  /*
  @NoDoc override Obj? evalOrReadAll(Str src)
  {
    throw unsupported
  }
  */

  Err unsupported() { UnsupportedErr("TestAxonContext") }
}

