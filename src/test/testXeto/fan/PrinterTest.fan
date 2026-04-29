//
// Copyright (c) 2025, Brian Frank
// All Rights Reserved
//
// History:
//   29 Aug 2025  Brian Frank  Creation
//

using xeto
using xetom
using haystack

**
** PrinterTest
**
@Js
class PrinterTest : AbstractXetoTest
{
  StrBuf buf := StrBuf()
  Namespace? ns

  override Void setup()
  {
    ns = createNamespace(["hx.test.xeto"])
  }

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  Void testInstances()
  {
    // basic instance
    opts := Etc.dictSet(qnameForce, "noSort", m)
    out := newCase(opts)
    out.instance(Etc.makeDict(["id":Ref("foo")]))
    verifyInstance(
      Str<|@foo: {}
          |>)

    // instance with spec tag
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"), "spec",Ref("hx.test.xeto::TestSite")))
    verifyInstance(
      Str<|@foo: hx.test.xeto::TestSite {}
          |>)

    // instance with different data types
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"), "marker",m, "str","hello", "date",Date("2025-08-29"), "num",n(123, "%")))
    verifyInstance(
      Str<|@foo: {
             marker
             str: "hello"
             date: sys::Date 2025-08-29
             num: sys::Number 123%
           }
           |>)

    // with noSort
    out = newCase(Etc.dictRemove(opts, "noSort"))
    out.instance(Etc.dictx("id",Ref("foo"), "marker",m, "str","hello", "date",Date("2025-08-29"), "num",n(123, "%")))
    verifyInstance(
      Str<|@foo: {
             date: sys::Date 2025-08-29
             marker
             num: sys::Number 123%
             str: "hello"
           }
           |>)

    // instance with refs
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"), "a",Ref("abc"), "b",Ref("xyz-123", "Display")))
    verifyInstance(
      Str<|@foo: {
             a: @abc
             b: @xyz-123 "Display"
           }
           |>)

    // instance with encoded strings
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"), "a",Str<|$<foo>|>, "b",Str<|_"x"_|>, "c","\u{0} \u{1f} \t \\ \$"))
    verifyInstance(
      Str<|@foo: {
             a: "$<foo>"
             b: "_\"x\"_"
             c: "\u{0} \u{1f} \t \\ $"
           }
           |>)

    // instance with multiline string
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"), "multi", "alpha\nbeta\ngamma", "b","single"))
    verifyInstance(
      Str<|@foo: {
             multi: ---
               alpha
               beta
               gamma
               ---
             b: "single"
           }
           |>)

    // instance with untyped nested dicts
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"),
      "dict0",Etc.dict0,
      "dict1",Etc.dict1("foo","bar"),
      "dict2",Etc.dict2("foo","bar", "baz",m)))
    verifyInstance(
      Str<|@foo: {
             dict0: {}
             dict1: {
               foo: "bar"
             }
             dict2: {
               foo: "bar"
               baz
             }
           }
           |>)

    // instance with typed nested dicts
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"),
      "dict0",Etc.dict1("spec",Ref("ph::Site")),
      "dict1",Etc.dict2("foo","bar", "spec",Ref("ph::Equip")),
      "dict2",Etc.dict3("foo","bar", "baz",m, "spec",Ref("ph::Point"))))
    verifyInstance(
      Str<|@foo: {
             dict0: ph::Site {}
             dict1: ph::Equip {
               foo: "bar"
             }
             dict2: ph::Point {
               foo: "bar"
               baz
             }
           }
           |>)

    // instance with typed nested dicts and ids
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("foo"),
      "dict0",Etc.dict2("id",Ref("a"), "spec",Ref("ph::Site")),
      "dict1",Etc.dict3("id",Ref("b"), "foo","bar", "spec",Ref("ph::Equip")),
      "dict2",Etc.dict4("id",Ref("c", "ignore"), "foo","bar", "baz",m, "spec",Ref("ph::Point"))))
    verifyInstance(
      Str<|@foo: {
             dict0 @a: ph::Site {}
             dict1 @b: ph::Equip {
               foo: "bar"
             }
             dict2 @c: ph::Point {
               foo: "bar"
               baz
             }
           }
           |>)

    // Namespace.writeData
    out = newCase(opts)
    out.data([Etc.dictx("id",Ref("foo"), "spec",Ref("ph::Site")),
              Etc.dictx("id",Ref("bar"), "spec",Ref("ph::Site"), "site",m),
              Etc.dictx("id",Ref("baz"), "spec",Ref("ph::Site")),
              ])
    verifyInstance(
      Str<|@foo: ph::Site {}

           @bar: ph::Site {
             site
           }

           @baz: ph::Site {}
           |>)
  }

  Void verifyInstance(Str expect)
  {
    actual := verifyOutput(expect)

    // verify we can parse as instance
    dict := ns.io.readXeto(actual, Etc.dict1("externRefs", m))
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  Void testSpecs()
  {
    lib  := ns.lib("hx.test.xeto")
    date := ns.spec("sys::Date")
    opts := Etc.dict1("noSort", m)

    // TestPrintA
    a := lib.spec("TestPrintA")
    dateMeta := Etc.dictToMap(date.meta)
    dateMeta.set("maybe", m)
    dateMeta.remove("sealed")
    verifySpecMeta(a.slot("date1"), date, dateMeta.dup.set("val", Date("2026-04-20")))
    verifySpecMeta(a.slot("date2"), date, dateMeta.dup.set("val", Date("2026-04-20")) { remove("maybe") })
    verifySpecMeta(a.slot("date3"), date, dateMeta.dup.set("val", Date("2026-04-20")))
    verifySpecMeta(a.slot("date4"), date, dateMeta.dup.set("val", Date("2026-04-20")))
    verifySpecMeta(a.slot("date5"), date, dateMeta.dup.set("val", Date("2026-04-20")).set("metaQ",m))
    verifySpecMeta(a.slot("date6"), date, dateMeta.dup.set("metaQ",m).set("metaStr", "src code"))
    verifySpecMeta(a.slot("date7"), date, dateMeta.dup.set("metaQ",m).set("doc", "comment") { remove("maybe") })
    newCase(opts).spec(a)
    verifyOutput(
       Str<|TestPrintA: TestPrint {
              date1: 2026-04-20
              date2: Date 2026-04-20
              date3: 2026-04-20
              date4: 2026-04-20
              date5: <metaQ> 2026-04-20
              date6: <metaQ, metaStr:"src code">
              // comment
              date7: Date <metaQ>
            }
            |>)

    // TestPrintB
    b := lib.spec("TestPrintB")
    newCase(opts).spec(b)
    verifyOutput(
       Str<|TestPrintB: TestPrint {
              meta1: Dict <metaStr:"">
              meta2: Dict <metaStr:"foo bar">
              meta3: Dict <metaQ> {
                <metaStr: ---
                foo
                bar
                --->
              }
              <axon: ---
              line 1
              line 2
              --->
            }
            |>)

    // TestPrintC
    c := lib.spec("TestPrintC")
    newCase(opts).spec(c)
    verifyOutput(
       Str<|TestPrintC: TestPrint {
              sv1: StatusNumber {
                val: 123
              }
              sv2: <val:StatusNumber {
                val: 123
                status: Status {}
              }>
            }
            |>)

    // TestPrintD
    d := lib.spec("TestPrintD")
    newCase(opts).spec(d)
    verifyOutput(
       Str<|TestPrintD: TestPrint {
              marker1
              marker2: Marker <admin>
              marker3: Marker?
              marker4: Marker? <admin>
              marker5: Marker? {
                <axon: ---
                foo
                bar
                --->
              }
            }
            |>)

    // TestPrintE
    e := lib.spec("TestPrintE")
    newCase(opts).spec(e)
    verifyOutput(
       Str<|TestPrintE: TestPrint {
              s1: ""
              s2: 123
              s3: 123.4
              s4: 123.4gH₂O/kgAir
              s5: "123.4gH₂O/kgAir 123"
            }
            |>)

    // TestPrintE with different options
    newCase(Etc.dict2("showInferredTypes", m, "quoteNums", m)).spec(e)
    verifyOutput(
       Str<|TestPrintE: TestPrint {
              s1: Str? ""
              s2: Str? "123"
              s3: Str? "123.4"
              s4: Str? "123.4gH₂O/kgAir"
              s5: Str? "123.4gH₂O/kgAir 123"
            }
            |>)
  }

  Void verifySpecMeta(Spec spec, Spec type, Str:Obj expectMeta)
  {
    actualMeta := spec.meta
    // echo("~~ $spec | $spec.type | $actualMeta")
    verifySame(spec.type, type)
    verifyDictEq(actualMeta, expectMeta)
  }

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  Void testAst()
  {
    verifyAst(
      Str<|Foo: Dict {}|>,
      Str<|Foo: sys::Dict
           |>)

    verifyAst(
      Str<|Foo: Dict <abstract, axon:"src", su>|>,
      Str<|Foo: sys::Dict <su, abstract, axon:"src">
           |>)

    verifyAst(
      Str<|// documentation
           // line 2
           Foo: Dict {
             dis: Str? <transient>  // display
           }|>,
      Str<|// documentation
           // line 2
           Foo: sys::Dict {
             // display
             dis: sys::Str? <transient>
           }
           |>)

    verifyAst(
      Str<|// documentation
           Foo: Ahu & Vav & Fcu <admin> {
             dis: Str? <axon:"src">
           }|>,
      Str<|// documentation
           Foo: ph::Ahu & ph::Vav & ph::Fcu <admin> {
             dis: sys::Str? <axon:"src">
           }
           |>)
  }

  Void verifyAst(Str src, Str expect)
  {
    ast := ns.io.readAst(src)
    newCase(qnameForce).ast(ast)
    verifyOutput(expect)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Dict qnameForce() { Etc.dict1("qnameForce", m) }

  XetoPrinter newCase(Dict? opts := null)
  {
    buf.clear
    return XetoPrinter(ns, buf.out, opts)
  }

  Str verifyOutput(Str expect)
  {
    actual := buf.toStr

    if (false)
    {
      echo
      echo("----")
      echo(actual.trimEnd)
      echo("----")
    }

    actualLines := actual.splitLines
    expectLines := expect.splitLines
    actualLines.each |actualLine, i|
    {
      expectLine := expectLines.getSafe(i)
      if (actualLine != expectLine)
      {
        echo("Failed line ${i+i}")
        echo("  $actualLine")
        echo("  $expectLine")
      }
      verifyEq(actualLine, expectLine)
    }
    verifyEq(actual, expect)
    return actual
  }
}

