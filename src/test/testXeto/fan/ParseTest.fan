//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2025  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** ParseTest
**
@Js
class ParseTest : AbstractXetoTest
{

  Void test()
  {
    ns := createNamespace(["sys", "ph", "hx.test.xeto"])
    s := Ref("sys::Spec")

    verifyParse(ns,
      Str<|Foo: Dict|>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      ])

    verifyParse(ns,
      Str<|Foo: {}|>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      ])

    verifyParse(ns,
      Str<|Foo: Ahu|>,
      [
        ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s]
      ])

    verifyParse(ns,
      Str<|Foo: ph::Ahu <metaQ, metaR:"Marker", q:"2025-10-17">|>,
      [
        ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s, "metaQ":m, "metaR":m, "q":Date("2025-10-17")]
      ])

    verifyParse(ns,
      Str<|Foo: Dict {
             m
             a: Str
             b: Str "hi"
             d: Date <metaQ> "2025-10-18"
           }|>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "slots":Etc.dictFromMap([
           "m": Etc.dictFromMap(["type":Ref("sys::Marker")]),
           "a": Etc.dictFromMap(["type":Ref("sys::Str"),  ]),
           "b": Etc.dictFromMap(["type":Ref("sys::Str"),  "val":"hi"]),
           "d": Etc.dictFromMap(["type":Ref("sys::Date"), "metaQ":m, "val":Date("2025-10-18")]),
           ])
        ]
      ])
  }

  Void verifyParse(LibNamespace ns, Str src, Obj[] expect)
  {
    // echo; echo("########"); echo(src)
    actual := ns.parseToDicts(src)
    // actual.each |a, i| { if (i > 0) echo("---"); Etc.dictDump(a) }
    actual.each |a, i|
    {
      e := expect[i]
      verifyDictEq(a, e)
    }
    verifyEq(actual.size, expect.size)
  }
}

