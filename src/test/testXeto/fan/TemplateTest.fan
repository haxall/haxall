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

    // testTemplateBindA
    dict := (Dict)call("testTemplateBindA", ["test str"])
    verifyDictEq(dict, ["dis":"Test", "foo":m, "x":"test str", "y":n(123)])

    // ### If ###

    // testTemplateIfA
    dict = call("testTemplateIfA", [true])
    verifyDictEq(dict, ["dis":"cond is true"])
    dict = call("testTemplateIfA", [false])
    verifyDictEq(dict, [:])

    // testTemplateIfB
    dict = call("testTemplateIfB", [true])
    verifyDictEq(dict, ["dis":"cond is true", "yea":m])
    dict = call("testTemplateIfB", [false])
    verifyDictEq(dict, ["dis":"cond is false", "nay":m])

    // ### Switch ###

    // testTemplateSwitchB
    dict = call("testTemplateSwitchA", ["a"])
    verifyDictEq(dict, ["dis":"case a"])
    dict = call("testTemplateSwitchA", ["b"])
    verifyDictEq(dict, ["dis":"case b"])
    dict = call("testTemplateSwitchA", ["c"])
    verifyDictEq(dict, ["dis":"case default"])

    // ### Foreach ###

    // testTemplateForeachA
    dict = call("testTemplateForeachA", [["a", "b", "c"]])
    expect := ["_0":Etc.dict1("dis", "a"), "_1":Etc.dict1("dis", "b"), "_2":Etc.dict1("dis", "c") ]
    verifyDictEq(dict, expect)

    // testTemplateForeachB
    dict = call("testTemplateForeachB", [["a", "b", "c"]])
    verifyDictEq(dict, expect)
  }

  Obj? call(Str name, Obj?[] args)
  {
    makeContext.asCur |->Obj?|
    {
      res := ns.unqualifiedFunc(name).func.thunk.callList(args)
echo("$name => $res [$res.typeof]")
      return res
    }
  }
}

