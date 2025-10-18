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

    // basics
    verifyParse(ns,
      Str<|Foo: Dict|>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      ])

    // infer base type
    verifyParse(ns,
      Str<|Foo: {}|>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      ])

    // base type in ph
    verifyParse(ns,
      Str<|Foo: Ahu|>,
      [
        ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s]
      ])

    // type slots
    verifyParse(ns,
      Str<|Foo: ph::Ahu <metaQ, metaR:"Marker", q:"2025-10-17">|>,
      [
        ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s, "metaQ":m, "metaR":m, "q":Date("2025-10-17")]
      ])

    // slots
    verifyParse(ns,
      Str<|Foo: Dict {
             m
             a: Str?
             b: Str "hi"
             d: Date <metaQ> "2025-10-18"
             x: Foo
             y: "just val"
           }|>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "slots":Etc.dictFromMap([
           "m": Etc.dictFromMap(["type":Ref("sys::Marker")]),
           "a": Etc.dictFromMap(["type":Ref("sys::Str"),  "maybe":m]),
           "b": Etc.dictFromMap(["type":Ref("sys::Str"),  "val":"hi"]),
           "d": Etc.dictFromMap(["type":Ref("sys::Date"), "metaQ":m, "val":Date("2025-10-18")]),
           "x": Etc.dictFromMap(["type":Ref("proj::Foo") ]),
           "y": Etc.dictFromMap(["val":"just val"]),
           ])
        ]
      ])

    // nested slots
    verifyParse(ns,
      Str<|Foo: Dict {
             Box {
               Label { text:"a" }
               Label { text:"b" }
             }
           }|>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "slots":Etc.dictFromMap([
           "_0": Etc.dictFromMap(["type":Ref("Box"), "slots":Etc.dictFromMap([
             "_0": Etc.dictFromMap(["type":Ref("Label"), "slots":Etc.dict1("text", Etc.dictFromMap(["val":"a"])) ]),
             "_1": Etc.dictFromMap(["type":Ref("Label"), "slots":Etc.dict1("text", Etc.dictFromMap(["val":"b"])) ])
             ]),
           ])
         ])
        ]
      ])

    // resolved types become non-qname refs
    opts = Etc.makeDict(["libName":"foo.bar"])
    verifyParse(ns,
      Str<|Foo: TSwift {
             a: Str
             b: Foo
             c: TooMuchJoy
           }|>,
      [
        ["name":"Foo", "base":Ref("TSwift"), "spec":Ref("sys::Spec"), "slots":Etc.dictFromMap([
           "a": Etc.dictFromMap(["type":Ref("sys::Str")]),
           "b": Etc.dictFromMap(["type":Ref("foo.bar::Foo"),  ]),
           "c": Etc.dictFromMap(["type":Ref("TooMuchJoy") ]),
           ])
        ]
      ])
    opts = null

    // instances, refs in instances not resolved to qnames
    verifyParse(ns,
      Str<|Foo: { n: Str }
           @x-a: Foo { n:"alpha" }
           @x.b: { n:"beta" }
           @x.c: Ahu { n:"charlie" }
           @x.d: {
             dict: {a:"nest", m}
             list: List { "a", "b" }
             ref1: Foo
             ref2: Ahu
           }
           |>,
      [
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "slots":Etc.dictFromMap([
           "n": Etc.dictFromMap(["type":Ref("sys::Str")]),
           ])
        ],
        ["name":"x-a", "spec":Ref("proj::Foo"), "n":"alpha"],
        ["name":"x.b", "n":"beta"],
        ["name":"x.c", "spec":Ref("ph::Ahu"),   "n":"charlie"],
        ["name":"x.d", "dict":Etc.dict2("a","nest", "m",m), "list":Obj?["a", "b"], "ref1":Ref("Foo"), "ref2":Ref("Ahu")],
      ])
  }

  Void verifyParse(LibNamespace ns, Str src, Obj[] expect)
  {
    // echo; echo("########"); echo(src)
    actual := ns.parseToDicts(src, opts)
    // actual.each |a, i| { if (i > 0) echo("---"); Etc.dictDump(a) }
    actual.each |a, i|
    {
      e := expect[i]
      verifyDictEq(a, e)
    }
    verifyEq(actual.size, expect.size)
  }

  Dict? opts
}

