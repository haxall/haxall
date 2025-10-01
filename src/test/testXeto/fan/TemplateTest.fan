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
    verifyDictEq(dict, ["dis":"Test", "foo":m, "x":"test str", "y":n(123), "spec":Ref("hx.test.xeto::TestFolder")])

    // testTemplateBindB
    dict = (Dict)call("testTemplateBindB", [Etc.dictx("a","Alpha", "b",n(2), "c",Etc.dict1("nest", "!"), "d",Date.today)])
    verifyDictEq(dict, ["a":"Alpha", "b":n(2), "c":"!", "d":Date.today])
    dict = (Dict)call("testTemplateBindB", [Etc.dictx("a","Alpha", "b",n(2), "c",Etc.dict1("nest", "!"), "d",Date.today, "e",Etc.dict1("nest", "^"))])
    verifyDictEq(dict, ["a":"Alpha", "b":n(2), "c":"!", "d":Date.today, "e":Etc.dict1("nest", "^"), "en":"^"])

    // testTemplateBindC
    dict = (Dict)call("testTemplateBindC", ["foo"])
    verifyDictEq(dict, [
      "spec":Ref("hx.test.xeto::TestFolder"),
      "nest": Etc.makeDict(["a":"foo", "b":"", "c":"def-c", "e":"foo", "spec":Ref("hx.test.xeto::TemplateDictC")]),
    ])

    // testTemplateBindD
    dict = (Dict)call("testTemplateBindD", [n(7), "foo bar"])
    verifyDictEq(dict, ["a":n(107), "b":"FOO BAR"])

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

    // testTemplateIfC
    dict = call("testTemplateIfC", [true, true])
    verifyDictEq(dict, ["dis1":"true", "dis2":"true"])
    dict = call("testTemplateIfC", [false, false])
    verifyDictEq(dict, ["dis1":"false"])

    // testTemplateIfD
    dict = call("testTemplateIfD", [n(99)])
    verifyDictEq(dict, ["dis":"less than 100"])
    dict = call("testTemplateIfD", [n(101)])
    verifyDictEq(dict, ["dis":"greater than 100"])

    // ### Switch ###

    // testTemplateSwitchA
    dict = call("testTemplateSwitchA", ["a"])
    verifyDictEq(dict, ["dis":"case a", "alpha":m])
    dict = call("testTemplateSwitchA", ["b"])
    verifyDictEq(dict, ["dis":"case b", "beta":m])
    dict = call("testTemplateSwitchA", ["c"])
    verifyDictEq(dict, ["dis":"case default"])

    // testTemplateSwitchB
    dict = call("testTemplateSwitchB", ["alpha"])
    verifyDictEq(dict, ["dis":"case a", "alpha":m])
    dict = call("testTemplateSwitchB", ["Beta"])
    verifyDictEq(dict, ["dis":"case b", "beta":m])
    dict = call("testTemplateSwitchB", ["foo"])
    verifyDictEq(dict, ["dis":"case default"])

    // testTemplateSwitchC
    dict = call("testTemplateSwitchC", [n(3), n(5), n(10)])
    verifyDictEq(dict, ["dis1":"odd", "dis2":"odd"])
    dict = call("testTemplateSwitchC", [n(8), n(5), n(10)])
    verifyDictEq(dict, ["dis1":"less than 10", "dis2":"odd"])
    dict = call("testTemplateSwitchC", [n(8), n(5), n(6)])
    verifyDictEq(dict, ["dis1":"else >= 6", "dis2":"odd"])
    dict = call("testTemplateSwitchC", [n(9), n(5), n(6)])
    verifyDictEq(dict, ["dis1":"odd", "dis2":"odd"])
    dict = call("testTemplateSwitchC", [n(9), n(12), n(6)])
    verifyDictEq(dict, ["dis1":"odd", "dis2":"else >= 6"])
    dict = call("testTemplateSwitchC", [n(9), n(4), n(6)])
    verifyDictEq(dict, ["dis1":"odd", "dis2":"less than 6"])

    // ### Foreach ###

    // testTemplateForeachA
    list := call("testTemplateForeachA", [["a", "b", "c"]])
    verifyValEq(list, Obj?["a", "b", "c"])

    // testTemplateForeachB
    dict = call("testTemplateForeachB", [["a", "b", "c"]])
    expect := ["_0":Etc.dict1("dis", "a"), "_1":Etc.dict1("dis", "b"), "_2":Etc.dict1("dis", "c") ]
    verifyDictEq(dict, expect)

    // testTemplateForeachC
    dict = call("testTemplateForeachC", [["a", "b"]])
    verifyDictEq(dict, [
      "nestDict": Etc.dictx("_0","a", "_1","b"),
      "nestList": Obj?["a", "b"],
      "nestGrid": Etc.makeMapsGrid(null, [ ["dis":"a"], ["dis":"b"] ]),
      "_0": "a",
      "_1": "b",
    ])

    // testTemplateForeachD
    dict = call("testTemplateForeachD", [[n(0), n(1), n(2), n(3), n(4)]])
    verifyDictEq(dict, ["a":Obj?[n(101), n(103)]])
  }

  Obj? call(Str name, Obj?[] args)
  {
    makeContext.asCur |->Obj?|
    {
      res := ns.unqualifiedFunc(name).func.thunk.callList(args)
      // echo("$name => $res [$res.typeof]")
      return res
    }
  }
}

