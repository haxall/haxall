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

    // factory mapping
    a := xns.spec("hx.test.xeto::IFoo")
    verifyEq(a.isInterface, true)
    verifyEq(a.fantomType, IFoo#)

    // static methods
    verifyEval("IFoo.staticStr", "hi static!")
    verifyEval("IFoo.staticStr()", "hi static!")
    verifyEval("IFoo.staticAdd(30, 40)", n(70))
    verifyEval("hx.test.xeto::IFoo.staticStr()", "hi static!")
    verifyEval("hx.test.xeto::IFoo.staticAdd(30, 40)", n(70))

    // constructor - make with no arg
    expect := IFoo()
    verifyEval("IFoo.make", expect)
    verifyEval("IFoo.make()", expect)
    verifyEval("hx.test.xeto::IFoo.make", expect)
    verifyEval("hx.test.xeto::IFoo.make()", expect)
    verifyEval("IFoo()", expect)
    verifyEval("hx.test.xeto::IFoo()", expect)

    // constructor - make with arg
    expect = IFoo("baz")
    verifyEval("""IFoo.make("baz")""", expect)
    verifyEval("""IFoo("baz")""", expect)
    verifyEval("""hx.test.xeto::IFoo.make("baz")""", expect)
    verifyEval("""hx.test.xeto::IFoo("baz")""", expect)

    // instance methods
    /*
    verifyEval("""IFoo().str""", "hi noname")
    verifyEval("""IFoo().add(3, 4)""", "noname 7")
    verifyEval("""IFoo("brian").str""", "hi brian")
    verifyEval("""IFoo("brian").add(3, 4)""", "brian 7")
    */
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
    acc["IFoo"] = InterfaceSpecFactory(IFoo#)
    return acc
  }
}

**************************************************************************
** IFoo
**************************************************************************

@Js
const class IFoo {

  new make(Str name := "noname") { this.name = name }

  const Str name

  static Str staticStr() { "hi static!" }
  static Number staticAdd(Number a, Number b) { a + b }

  Str str() { "hi $name!" }
  Str add(Number a, Number b) { "$name " + (a + b) }

  override Int hash()
  {
    name.hash
  }

  override Bool equals(Obj? that)
  {
    name == ((IFoo)that).name
  }
}

