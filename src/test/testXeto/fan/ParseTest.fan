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

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  Void testAst()
  {
    ns := createNamespace(["sys", "ph", "hx.test.xeto"])
    s := Ref("sys::Spec")
    Dict? opts := null

    // basics
    verifyAst(ns, opts,
      Str<|Foo: Dict|>,
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      )

    // infer base type
    verifyAst(ns, opts,
      Str<|Foo: {}|>,
      ["name":"Foo", "base":Ref("sys::Dict"), "spec":s]
      )

    // base type in ph
    verifyAst(ns, opts,
      Str<|Foo: Ahu|>,
      ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s]
      )

    // type slots
    verifyAst(ns, opts,
      Str<|Foo: ph::Ahu <metaQ, metaR:"Marker", q:"2025-10-17">|>,
      ["name":"Foo", "base":Ref("ph::Ahu"), "spec":s, "metaQ":m, "metaR":m, "q":Date("2025-10-17")]
      )

    // slots
    verifyAst(ns, opts,
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
    verifyAst(ns, opts,
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
    verifyAst(ns, opts,
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
    verifyAst(ns, opts,
      Str<|Foo: { n: Str }
           |>,
        ["name":"Foo", "base":Ref("sys::Dict"), "spec":Ref("sys::Spec"),
           "slots":Etc.makeMapGrid(null, ["name":"n", "type":Ref("sys::Str")])]
      )

    // refs in instances not resolved to qnames
    verifyAst(ns, opts,
      Str<|@x-a: Foo { n:"alpha" }
           |>,
        ["name":"x-a", "spec":Ref("proj::Foo"), "n":"alpha"]
      )

    // refs in instances not resolved to qnames
    verifyAst(ns, opts,
      Str<|@x.b: { n:"beta" }
           |>,
        ["name":"x.b", "n":"beta"]
      )

    // refs in instances not resolved to qnames
    verifyAst(ns, opts,
      Str<|@x.c: Ahu { n:"charlie" }
           |>,
        ["name":"x.c", "spec":Ref("ph::Ahu"),   "n":"charlie"]
      )

    // refs in instances not resolved to qnames
    verifyAst(ns, opts,
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

  Void verifyAst(Namespace ns, Dict? opts, Str src, Str:Obj expect, Bool roundtrip := true)
  {
    // if (!roundtrip) echo("------"); else echo("\n######"); echo(src)
    actual := ns.io.readAst(src, opts)
    // actual.each |a, i| { if (i > 0) echo("---"); Etc.dictDump(a) }
    verifyDictEq(actual, expect)

    if (roundtrip)
    {
      src2 := ns.io.writeAstToStr(actual, opts)
      verifyAst(ns, opts, src2, expect, false)
    }

  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  Void testAxon()
  {
    ns := createNamespace(["sys", "ph", "hx.test.xeto"])
    s := Ref("sys::Spec")
    Dict? opts := null

    // basics
    verifyAxon(ns, opts,
      Str<|(a)   =>   echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Obj"), "maybe":m],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // double =>
    verifyAxon(ns, opts,
      Str<|(a) => do f: () => curFunc(); f(); end|>,
        [
          ["name":"a", "type":Ref("sys::Obj"), "maybe":m],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """do f: () => curFunc(); f(); end""",
        null)

    // basics
    verifyAxon(ns, opts,
      Str<|(a) => do
             echo("hello")
           end|>,
        [
          ["name":"a", "type":Ref("sys::Obj"), "maybe":m],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """do
             echo("hello")
           end""",
        null)

    // basics
    verifyAxon(ns, opts,
      Str<|(a, b, c) =>
           do
             echo("hello")
           end|>,
        [
          ["name":"a", "type":Ref("sys::Obj"), "maybe":m],
          ["name":"b", "type":Ref("sys::Obj"), "maybe":m],
          ["name":"c", "type":Ref("sys::Obj"), "maybe":m],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """do
             echo("hello")
           end""",
        null)

    // simple types with/without maybe
    verifyAxon(ns, opts,
      Str<|(a: Str, b: Str?) => echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Str")],
          ["name":"b", "type":Ref("sys::Str"), "maybe":m],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // qname types with/without maybe
    verifyAxon(ns, opts,
      Str<|(a: sys::Str, b: hx.test.xeto::TestSite?) => echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Str")],
          ["name":"b", "type":Ref("hx.test.xeto::TestSite"), "maybe":m],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // return type simple
    verifyAxon(ns, opts,
      Str<|(): Str => echo("hello")|>,
        [
          ["name":"returns", "type":Ref("sys::Str")],
        ],
        """echo("hello")""",
        null)

    // return type qname
    verifyAxon(ns, opts,
      Str<|(): sys::Str => echo("hello")|>,
        [
          ["name":"returns", "type":Ref("sys::Str")],
        ],
        """echo("hello")""",
        null)

    // return type qname with meta
    verifyAxon(ns, opts,
      Str<|(): sys::Str? < foo , bar:"!", axon:"woof!"> => echo("hello")|>,
        [
          ["name":"returns", "type":Ref("sys::Str"), "maybe":m, "foo":m, "bar":"!", "axon":"woof!"],
        ],
        """echo("hello")""",
        null)

    // meta
    verifyAxon(ns, opts,
      Str<|(a: Str <foo>, b: hx.test.xeto::TestSite? <bar, baz:"!">, c: Obj? <qux>) => echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Str"), "foo":Marker.val],
          ["name":"b", "type":Ref("hx.test.xeto::TestSite"), "maybe":m, "bar":Marker.val, "baz":"!"],
          ["name":"c", "type":Ref("sys::Obj"), "maybe":m, "qux":Marker.val],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // def expr - literals
    verifyAxon(ns, opts,
      Str<|(a: 123, b: "s", c: null) => echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Obj"), "maybe":m, "axon":"123"],
          ["name":"b", "type":Ref("sys::Obj"), "maybe":m, "axon":"\"s\""],
          ["name":"c", "type":Ref("sys::Obj"), "maybe":m, "axon":"null"],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // def expr - express
    verifyAxon(ns, opts,
      Str<|(a: now(), b: 3 + 2, c: foo < 3) => echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Obj"), "maybe":m, "axon":"now()"],
          ["name":"b", "type":Ref("sys::Obj"), "maybe":m, "axon":"3 + 2"],
          ["name":"c", "type":Ref("sys::Obj"), "maybe":m, "axon":"foo < 3"],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // def expr - with simple types
    verifyAxon(ns, opts,
      Str<|(a: Date now(1, 2), b: Str 3 + 2, c: hx.test.xeto::TestSite foo < 3) => echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Date"), "axon":"now(1, 2)"],
          ["name":"b", "type":Ref("sys::Str"),  "axon":"3 + 2"],
          ["name":"c", "type":Ref("hx.test.xeto::TestSite"),  "axon":"foo < 3"],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // def expr - with qname types
    verifyAxon(ns, opts,
      Str<|(a: sys::Date now(1, 2), b: sys::Str x, c: Obj foo < 3) => echo("hello")|>,
        [
          ["name":"a", "type":Ref("sys::Date"), "axon":"now(1, 2)"],
          ["name":"b", "type":Ref("sys::Str"),  "axon":"x"],
          ["name":"c", "type":Ref("sys::Obj"),  "axon":"foo < 3"],
          ["name":"returns", "type":Ref("sys::Obj"), "maybe":m],
        ],
        """echo("hello")""",
        null)

    // comment slash/start single line
    verifyAxon(ns, opts,
      Str<|/* comment 1 */
           () => echo("hello")|>,
        [["name":"returns", "type":Ref("sys::Obj"), "maybe":m]],
        """echo("hello")""",
        "comment 1")

    // comment slash/start single line w/ funny whitespace
    verifyAxon(ns, opts,
      Str<|

              /*   comment 1   */


           () => echo("hello")|>,
        [["name":"returns", "type":Ref("sys::Obj"), "maybe":m]],
        """echo("hello")""",
        "comment 1")

    // comment slash/start single with newlines
    verifyAxon(ns, opts,
      Str<|
             /*

             comment 1

             */

           () => echo("hello")|>,
        [["name":"returns", "type":Ref("sys::Obj"), "maybe":m]],
        """echo("hello")""",
        "comment 1")

    // comment slash/start multi-line
    verifyAxon(ns, opts,
      Str<|
           /*

           comment 1

             comment 2

           comment 3
            comment 4

           */

           () => echo("hello")|>,
        [["name":"returns", "type":Ref("sys::Obj"), "maybe":m]],
        """echo("hello")""",
        "comment 1\n\n  comment 2\n\ncomment 3\n comment 4")

    // comment slash/slash simple
    verifyAxon(ns, opts,
      Str<|//comment 1
           () => echo("hello")|>,
        [["name":"returns", "type":Ref("sys::Obj"), "maybe":m]],
        """echo("hello")""",
        "comment 1")

    // comment slash/slash simple
    verifyAxon(ns, opts,
      Str<|// comment 1
           () => echo("hello")|>,
        [["name":"returns", "type":Ref("sys::Obj"), "maybe":m]],
        """echo("hello")""",
        "comment 1")

    // comment slash/slash multi
    verifyAxon(ns, opts,
      Str<|
           // comment 1
           //   comment 2
           //
           // comment 3
           () => echo("hello")|>,
        [["name":"returns", "type":Ref("sys::Obj"), "maybe":m]],
        """echo("hello")""",
        "comment 1\n  comment 2\n\ncomment 3")
  }

  Void verifyAxon(Namespace ns, Dict? opts, Str src, [Str:Obj][] eslots, Str eaxon, Str? edoc , Bool roundtrip := true)
  {
    //if (!roundtrip) echo("------"); else echo("\n######"); echo(src)

    actual := ns.io.readAxon(src, opts)
    aaxon  := (Str)actual->axon
    aslots := (Grid)actual->slots
    adoc   := actual["doc"] as Str

    if (false)
    {
      echo
      echo("axon: $aaxon.toCode")
      echo("doc: ${adoc?.toCode}")
      echo("slots:"); aslots.dump
    }

    verifyEq(aaxon, eaxon)
    verifyEq(adoc, edoc)
    aslots.each |row, i|
    {
      verifyDictEq(row, eslots[i])
    }
    verifyEq(aslots.size, eslots.size)

    if (roundtrip)
    {
      src2 := ns.io.writeAxonToStr(actual, opts)
      verifyAxon(ns, opts, src2, eslots, eaxon, edoc, false)
    }

  }

}

