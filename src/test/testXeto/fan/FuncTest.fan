//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Feb 2025  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack::Ref
using haystack::Dict
using haystack
using axon

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

    // Api - ping1
    f := lib.spec("ping1")
    verifyGlobalFunc(ns, f, [,], "sys::Date")
    verifyEq(f.func.api is ApiFunc, true)
    verifyEq(f.func.api->call(ApiReq()), Date.today)

    // Api - ping2 (missing facet)
    f = lib.spec("ping2")
    verifyGlobalFunc(ns, f, [,], "sys::Date")
    verifyEq(f.func.api(false), null)
    verifyErr(UnsupportedErr#) { f.func.api }

    // Axon
    verifyAxonAdd(ns, lib.spec("add1"), true)
    verifyAxonAdd(ns, lib.spec("add2"), true)
    verifyAxonAdd(ns, lib.spec("add3"), false)
  }

  private Void verifyAxonAdd(LibNamespace ns, Spec f, Bool hasAxon)
  {
    num := ns.spec("sys::Number")

    verifyGlobalFunc(ns, f, ["a: sys::Number", "b: sys::Number"], "sys::Number")

    if (!hasAxon)
    {
      verifyErr(UnsupportedErr#) { f.func.axon }
      return
    }

    Fn a := f.func.axon
    verifySame(f.func.axon, a)
    verifyEq(a.params.size, 2)
    verifyEq(a.params[0].name, "a")
    verifyEq(a.params[1].name, "b")
    cx := TextAxonContext(ns)
    verifyEq(a.call(cx, [n(3), n(5)]), n(8))
  }

  private Void verifyGlobalFunc(LibNamespace ns, Spec f, Str[] params, Str ret)
  {
    verifyEq(f.isGlobal, true)
    verifyEq(f.isFunc, true)
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

@Js
class TestApi
{
  @XetoApi static Date ping1(ApiReq req) { Date.today }

  // not available
  static Date ping2(ApiReq req) { Date.today }
}

**************************************************************************
** TextAxonContext
**************************************************************************

@Js
class TextAxonContext : AxonContext
{

  new make(LibNamespace ns) { this.xeto = ns }

//////////////////////////////////////////////////////////////////////////
// XetoContext
//////////////////////////////////////////////////////////////////////////

  override xeto::Dict? xetoReadById(Obj id) { throw unsupported }

  override Obj? xetoReadAllEachWhile(Str filter, |xeto::Dict->Obj?| f) { throw unsupported }

//////////////////////////////////////////////////////////////////////////
// HaystackContext
//////////////////////////////////////////////////////////////////////////

  override Dict? deref(Ref id) { throw unsupported }

  override once FilterInference inference() { throw unsupported }

  override Dict toDict() { Etc.dict0 }

//////////////////////////////////////////////////////////////////////////
// AxonContext
//////////////////////////////////////////////////////////////////////////

  override Namespace ns() { throw unsupported }

  override const LibNamespace xeto

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

