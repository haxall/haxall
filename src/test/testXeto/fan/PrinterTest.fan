//
// Copyright (c) 2025, Brian Frank
// All Rights Reserved
//
// History:
//   29 Aug 2025  Brian Frank  Creation
//

using xeto
using xetom
using xetoc
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

    // qualified id prints as its simple name
    out = newCase(opts)
    out.instance(Etc.dictx("id",Ref("some.lib::foo"), "dis","Foo"))
    verifyInstance(
      Str<|@foo: {
             dis: "Foo"
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
              date8: Date?
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
              marker5: Marker? <axon:---
                foo
                bar
                --->
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

    // enum: implied "sealed"/"val" meta and implied item types are
    // all dropped, otherwise the output does not parse back
    newCase(opts).spec(lib.spec("TestPrintEnum"))
    verifyOutput(
       Str<|TestPrintEnum: Enum {
              alpha
              beta
            }
            |>)

    // enum items keep their own meta
    newCase(opts).spec(lib.spec("TestPrintEnumKeys"))
    verifyOutput(
       Str<|TestPrintEnumKeys: Enum {
              utc <key:"UTC">
              newYork <key:"New_York">
            }
            |>)

    // a Ref "val" default uses "@id" syntax, not a quoted string
    newCase(opts).spec(lib.spec("InstantiateB"))
    verifyOutput(
       Str<|InstantiateB: InstantiateA {
              a: "alpha-b"
              b: "bravo-b"
              c: "charlie-b"
              icon: @hx.test.xeto::icon-b
              multiRef1: @hx.test.xeto::icon-a
              multiRef2: {
                 Dict @hx.test.xeto::icon-a
                 Dict @hx.test.xeto::icon-b
              }
            }
            |>)

    // an inline parameterized type is hoisted to a synthetic spec, which has
    // no source name - print it inline as its base type plus its own meta
    newCase(opts).spec(lib.spec("Sigs"))
    verifyOutput(
       Str<|Sigs: Dict {
              a: Str
              b: Str?
              c: A | B
              d: A & B
              e: A | B
              f: A & B
              g: List <of:sys::Str>
              h: List <of:Ref<of:A>>
            }
            |>)

    // a compound base declares its ofs on the spec itself, not on sys::And
    newCase(opts).spec(lib.spec("AB"))
    verifyOutput(
       Str<|// AB
            AB: A & B <qux:"AB", s:Date 2024-03-01> {
              z: Str
            }
            |>)

    // a mixin slot which overrides an inherited slot takes its type from
    // the base, so the type (and its colon) must not be restated
    newCase(opts).spec(lib.spec("Site"))
    verifyOutput(
       Str<|+Site <foo:"building"> {
              // no taek
              area <bar:"hello", foo:"AreaEditor">
              newSlot: Str <foo:"hi">
            }
            |>)

    // a mixin is declared by its "+" prefix, and its items are still enum
    // items even though the mixin spec itself is not the enum
    newCase(opts).spec(lib.spec("CurStatus"))
    verifyOutput(
       Str<|+CurStatus <qux:"_self_"> {
              ok <foo:"green">
              down <foo:"yellow">
              fault <foo:"red">
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
// Round Trip
//////////////////////////////////////////////////////////////////////////

  ** Print every top level spec of hx.test.xeto, recompile the printed
  ** source as its own lib, and verify each spec survived the round trip.
  ** This is the broad net: the printer must emit parsable source for
  ** every spec shape the test lib exercises.
  Void testRoundTrip()
  {
    lib  := ns.lib("hx.test.xeto")
    tops := lib.specs.list.findAll |x| { includeInRoundTrip(x) }

    // print all top level specs
    src := StrBuf()
    printer := XetoPrinter(ns, src.out, Etc.dict1("qnameForce", m))
    tops.each |x| { printer.spec(x); src.add("\n") }

    // print all instances, except those which the source declares nested
    // inside another instance - printing those standalone duplicates them
    nested := Str:Str[:]
    lib.instances.each |x|
    {
      x.each |v, n| { if (v is Dict) { id := ((Dict)v)["id"] as Ref; if (id != null) nested[id.id] = n } }
    }
    tinsts := lib.instances.findAll |x| { !nested.containsKey(x->id.toStr) }

    insts := StrBuf()
    instPrinter := XetoPrinter(ns, insts.out, Etc.dict1("qnameForce", m))
    tinsts.each |x| { instPrinter.instance(x); insts.add("\n") }

    // stage as a lib which depends on the original
    dir := tempDir + `roundtrip/`
    dir.delete
    dir.create
    (dir + `lib.xeto`).out.print(roundTripPragma(lib)).close
    (dir + `specs.xeto`).out.print(src.toStr).close
    (dir + `instances.xeto`).out.print(insts.toStr).close

    // recompile under the same lib name so every qualified id in the
    // printed source still resolves; the namespace holds only its depends
    // so the original lib is not also in scope
    Lib? rt := null
    try
      rt = XetoCompiler.init |c|
      {
        c.ns      = createNamespace(lib.depends.map |d->Str| { d.name })
        c.libName = lib.name
        c.input   = dir
        c.build   = tempDir + `roundtrip.xetolib`
      }.compileLib
    catch (Err e)
      fail("Cannot recompile printed source: $e.msg")

    // every spec made it across with the same shape; the recompiled lib
    // hoists its own synthetics for inline parameterized types, so compare
    // only the specs which were actually named in the source
    verifyEq(rt.specs.list.findAll |x| { !XetoUtil.isAutoName(x.name) }.size, tops.size)
    tops.each |x|
    {
      a := rt.spec(x.name)
      verifyEq(a.base?.name, x.base?.name, x.name)
      verifyEq(a.isEnum,  x.isEnum,  x.name)
      verifyEq(a.isMixin, x.isMixin, x.name)
      verifyEq(a.slotsOwn.names.dup.sort, x.slotsOwn.names.dup.sort, x.name)
    }

    // every instance made it across with the same tags
    verifyEq(rt.instances.size, lib.instances.size)
    tinsts.each |x|
    {
      name := XetoUtil.qnameToName(x->id) ?: x->id.toStr
      a := rt.instance(name)
      verifyEq(a.get("spec")?.toStr, x.get("spec")?.toStr, name)
      verifyEq(Etc.dictNames(a).sort, Etc.dictNames(x).sort, name)
    }
  }

  ** A synthetic top hoisted from an inline parameterized type has no
  ** source name of its own, so it is never printed standalone.
  private Bool includeInRoundTrip(Spec x) { !XetoUtil.isAutoName(x.name) }

  ** Minimal pragma carrying the same depends as the lib being round tripped
  private Str roundTripPragma(Lib lib)
  {
    s := StrBuf()
    s.add("pragma: Lib <\n  doc: \"round trip\"\n  version: \"0.0.1\"\n  depends: {\n")
    lib.depends.each |d| { s.add("    { lib: ").add(d.name.toCode).add(" }\n") }
    s.add("  }\n  org: { dis: \"Test\", uri: \"http://test/\" }\n>\n")
    return s.toStr
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

    // a mixin prints with its "+" prefix on the AST path too, where the
    // "mixin" meta comes from the source rather than being derived
    verifyAst(
      Str<|+Foo <admin> {
             bar: Str?
           }|>,
      Str<|+Foo <admin> {
             bar: sys::Str?
           }
           |>)

    // only a slot may drop its type to print as a bare marker
    verifyAst(
      Str<|Foo: Marker {
             bar: Marker
           }|>,
      Str<|Foo: sys::Marker {
             bar
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

