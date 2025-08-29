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
  LibNamespace? ns

  Void testInstances()
  {
    ns = createNamespace(["hx.test.xeto"])

    // basic instance
    out := newCase
    out.instance(Etc.makeDict(["id":Ref("foo")]))
    verifyInstance(
      Str<|@foo: {}
          |>)

    // instance with spec tag
    out = newCase
    out.instance(Etc.dictx("id",Ref("foo"), "spec",Ref("hx.test.xeto::TestSite")))
    verifyInstance(
      Str<|@foo: hx.test.xeto::TestSite {}
          |>)

    // instance with different data types
    out = newCase
    out.instance(Etc.dictx("id",Ref("foo"), "marker",m, "str","hello", "date",Date("2025-08-29"), "num",n(123, "%")))
    verifyInstance(
      Str<|@foo: {
             marker
             str: "hello"
             date: sys::Date "2025-08-29"
             num: sys::Number "123%"
           }
           |>)

    // instance with refs
    out = newCase
    out.instance(Etc.dictx("id",Ref("foo"), "a",Ref("abc"), "b",Ref("xyz-123", "Display")))
    verifyInstance(
      Str<|@foo: {
             a: @abc
             b: @xyz-123 "Display"
           }
           |>)

    // instance with encoded strings
    out = newCase
    out.instance(Etc.dictx("id",Ref("foo"), "a",Str<|$<foo>|>, "b",Str<|_"x"_|>, "c","\u{0} \u{1f} \t \\ \$"))
    verifyInstance(
      Str<|@foo: {
             a: "$<foo>"
             b: "_\"x\"_"
             c: "\u{0} \u{1f} \t \\ $"
           }
           |>)

    // instance with multiline string
    out = newCase
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
    out = newCase
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
    out = newCase
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
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  XetoPrinter newCase()
  {
    buf.clear
    return XetoPrinter(ns, buf.out)
  }

  Void verifyInstance(Str expect)
  {
    actual := buf.toStr

    if (true)
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

    // verify we can parse as instance
    dict := ns.compileData(actual, Etc.dict1("externRefs", m))
  }
}

