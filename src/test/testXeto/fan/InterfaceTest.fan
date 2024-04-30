//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Apr 2024  Brian Frank  Creation
//

using xeto
using haystack
using haystack::Dict  // TODO: need Dict.id
using haystack::Ref
using axon
using folio
using hx

**
** InterfaceTest
**
class InterfaceTest : AbstractAxonTest
{

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testBasics()
  {
    initNamespace(["ph", "ph.points", "hx.test.xeto"])

    a := xns.spec("hx.test.xeto::IFoo")
    verifyEq(a.fantomType, IFoo#)

    x := eval("IFoo()")
echo(">>>> $x [$x.typeof]")

    verifyEval("IFoo().str", "working")
    verifyEval("IFoo().add(3, 4)", n(7))
  }
}

**************************************************************************
** XetoFactoryLoader
**************************************************************************

@Js
internal const class XetoFactoryLoader: SpecFactoryLoader
{
  override Bool canLoad(Str libName)
  {
    if (libName == "hx.test.xeto") return true
    return false
  }

  override Str:SpecFactory load(Str libName, Str[] specNames)
  {
    if (libName != "hx.test.xeto") throw Err(libName)
    pod := typeof.pod
    acc := Str:SpecFactory[:]
    acc["IFoo"] = InterfaceFactory(IFoo#)
    return acc
  }
}

@Js
internal const class InterfaceFactory : DictSpecFactory
{
  new make(Type type) : super(type) {}
  override Dict decodeDict(xeto::Dict m, Bool b := true) { IFoo(m) }
}

**************************************************************************
** IFoo
**************************************************************************

@Js
const class IFoo : WrapDict {
  new make(Dict m) : super(m) {}
  Str str() { "hi!" }
  Number add(Number a, Number b) { a + b }
}

