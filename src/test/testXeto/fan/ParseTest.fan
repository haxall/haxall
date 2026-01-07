//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Oct 2025  Brian Frank  Creation
//

using util
using xeto
using xetom
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
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      )

    // infer base type
    verifyParse(ns,
      Str<|Foo: {}|>,
      ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      )

    // base type in ph
    verifyParse(ns,
      Str<|Foo: Ahu|>,
      ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s]
      )

    // type slots
    verifyParse(ns,
      Str<|Foo: ph::Ahu <metaQ, metaR:"Marker", q:"2025-10-17">|>,
      ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s, "metaQ":m, "metaR":m, "q":Date("2025-10-17")]
      )

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
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "slots":Etc.makeMapsGrid(null, [
           ["name":"m", "type":Ref("sys::Marker")],
           ["name":"a", "type":Ref("sys::Str"),  "maybe":m],
           ["name":"b", "type":Ref("sys::Str"),  "val":"hi"],
           ["name":"d", "type":Ref("sys::Date"), "metaQ":m, "val":Date("2025-10-18")],
           ["name":"x", "type":Ref("proj::Foo") ],
           ["name":"y", "val":"just val"],
           ]).reorderCols(["name", "type", "maybe", "val", "metaQ"])
        ]
      )

    // nested slots
    verifyParse(ns,
      Str<|Foo: Dict {
             Box {
               Label { text:"a" }
               Label { text:"b" }
             }
           }|>,
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"), "slots":Etc.makeMapGrid(null, [
           "name":"_0",
           "type":Ref("proj::Box"),
           "slots":Etc.makeMapsGrid(null, [
             ["name":"_0", "type":Ref("proj::Label"), "slots":Etc.makeMapGrid(null, ["name":"text", "val":"a"]).reorderCols(["name", "val"]), ],
             ["name":"_1", "type":Ref("proj::Label"), "slots":Etc.makeMapGrid(null, ["name":"text", "val":"b"]).reorderCols(["name", "val"]), ]
             ]).reorderCols(["name", "type", "slots"]),
           ]).reorderCols(["name", "type", "slots"]),
        ]
      )

    // resolved types become non-qname refs
    opts = Etc.makeDict(["libName":"foo.bar"])
    verifyParse(ns,
      Str<|// Foo docs here
           Foo: TSwift {
             a: Str
             b: Foo
             c: TooMuchJoy
           }|>,
        ["name":"Foo", "base":Ref("foo.bar::TSwift"), "spec":Ref("sys::Spec"), "doc":"Foo docs here", "slots":Etc.makeMapsGrid(null, [
           ["name":"a", "type":Ref("sys::Str")],
           ["name":"b", "type":Ref("foo.bar::Foo"), ],
           ["name":"c", "type":Ref("foo.bar::TooMuchJoy") ],
           ])]
      )
    opts = null

    // dict
    verifyParse(ns,
      Str<|Foo: { n: Str }
           |>,
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"),
           "slots":Etc.makeMapGrid(null, ["name":"n", "type":Ref("sys::Str")])]
      )

    // refs in instances not resolved to qnames
    verifyParse(ns,
      Str<|@x-a: Foo { n:"alpha" }
           |>,
        ["name":"x-a", "spec":Ref("proj::Foo"), "n":"alpha"]
      )

    // refs in instances not resolved to qnames
    verifyParse(ns,
      Str<|@x.b: { n:"beta" }
           |>,
        ["name":"x.b", "n":"beta"]
      )

    // refs in instances not resolved to qnames
    verifyParse(ns,
      Str<|@x.c: Ahu { n:"charlie" }
           |>,
        ["name":"x.c", "spec":Ref("ph::Ahu"),   "n":"charlie"]
      )

    // refs in instances not resolved to qnames
    verifyParse(ns,
      Str<|@x.d: {
             dict: {a:"nest", m}
             list: List { "a", "b" }
             ref1: Foo
             ref2: Ahu
           }
           |>,
        ["name":"x.d", "dict":Etc.dict2("a","nest", "m",m), "list":Obj?["a", "b"], "ref1":Ref("proj::Foo"), "ref2":Ref("ph::Ahu")]
      )
  }

  Void verifyParse(Namespace ns, Str src, Str:Obj expect, Bool roundtrip := true)
  {
    // if (!roundtrip) echo("------"); else echo("\n######"); echo(src)
    actual := ns.io.readAst(src, opts)
    // actual.each |a, i| { if (i > 0) echo("---"); Etc.dictDump(a) }
    verifyDictEq(actual, expect)

    if (roundtrip)
    {
      src2 := ns.io.writeAstToStr(actual, opts)
      verifyParse(ns, src2, expect, false)
    }

  }

  Dict? opts
}

