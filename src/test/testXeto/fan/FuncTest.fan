//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Feb 2025  Brian Frank  Creation
//

using util
using xeto
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

    num := ns.spec("sys::Number")
    verifyEq(num.isGlobal, false)
    verifyEq(num.isType, true)
    verifyEq(num.isFunc, false)
    verifyErr(UnsupportedErr#) { num.func }


    verifyAdd(ns, lib.spec("add1"), true)
    verifyAdd(ns, lib.spec("add2"), true)
    verifyAdd(ns, lib.spec("add3"), false)
  }

  private Void verifyAdd(LibNamespace ns, Spec f, Bool hasAxon)
  {
    num := ns.spec("sys::Number")

    verifyEq(f.isGlobal, true)
    verifyEq(f.isFunc, true)
    verifyEq(f.func.arity, 2)
    verifyEq(f.func.params.size, 2)
    verifyEq(f.func.params[0].name, "a"); verifySame(f.func.params[0].type, num)
    verifyEq(f.func.params[1].name, "b"); verifySame(f.func.params[1].type, num)
    verifySame(f.func.returns.type, num)

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
}

**************************************************************************
** TextAxonContext
**************************************************************************

@Js
class TestAxonFuncs
{
  @Axon static Number add2(Number a, Number b) { a + b }

  // not available
  static Number add3(Number a, Number b) { a + b }
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

