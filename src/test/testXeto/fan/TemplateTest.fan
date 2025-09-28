//
// Copyright (c) 2025, Brian Frank
// All Rights Reserved
//
// History:
//   28 Sep 2025  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using hx

**
** TemplateTest
**
class TemplateTest : AbstractAxonTest
{

  @HxTestProj
  Void test()
  {
    ns := initNamespace(["hx.test.xeto"])

    a := ns.unqualifiedFunc("testTemplateA")
    d := (Dict)call("testTemplateA", ["test str"])
    verifyDictEq(d, ["dis":"Test", "foo":m, "x":"test str", "y":n(123)])
  }

  Obj? call(Str name, Obj?[] args)
  {
    makeContext.asCur |->Obj?|
    {
      res := ns.unqualifiedFunc(name).func.thunk.callList(args)
      return res
    }
  }
}

