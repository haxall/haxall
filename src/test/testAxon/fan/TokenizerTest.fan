//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2009  Brian Frank  Creation
//

using haystack
using axon

**
** TokenizerTest
**
@Js
class TokenizerTest : Test
{
  Void test()
  {
    // empty
    verifyToks("", Obj?[,])

    // identifiers
    verifyToks("x", Obj?[Token.id, "x"])
    verifyToks("fooBar", Obj?[Token.id, "fooBar"])
    verifyToks("fooBar1999x", Obj?[Token.id, "fooBar1999x"])
    verifyToks("foo_23", Obj?[Token.id, "foo_23"])

    // typename
    verifyToks("Str", Obj?[Token.typename, "Str"])
    verifyToks("Foo_23", Obj?[Token.typename, "Foo_23"])

    // ints
    verifyToks("5", Obj?[Token.val, n(5)])
    verifyToks("0x1234_abcd", Obj?[Token.val, n(0x1234_abcd)])

    // floats
    verifyToks("5.0", Obj?[Token.val, n(5f)])
    verifyToks("5.42", Obj?[Token.val, n(5.42f)])
    verifyToks("123.2e32", Obj?[Token.val, n(123.2e32f)])
    verifyToks("123.2e+32", Obj?[Token.val, n(123.2e32f)])
    verifyToks("2_123.2e+32", Obj?[Token.val, n(2_123.2e32f)])
    verifyToks("4.2e-7", Obj?[Token.val, n(4.2e-7f)])

    // numbers with units
    verifyToks("-40ms", Obj?[Token.minus, null, Token.val, n(40, "ms")])
    verifyToks("1sec", Obj?[Token.val, n(1, "s")])
    verifyToks("5hr", Obj?[Token.val, n(5, "hr")])
    verifyToks("2.5day", Obj?[Token.val, n(2.5f, "day")])
    verifyToks("12%", Obj?[Token.val, n(12, "%")])
    verifyToks("-1.2m/s", Obj?[Token.minus, null, Token.val, n(1.2f, "m/s")])
    verifyToks("12kWh/ft\u00B2", Obj?[Token.val, n(12, "kilowatt_hours_per_square_foot")])
    verifyToks("3_000.5J/kg_dry", Obj?[Token.val, n(3_000.5f, "joules_per_kilogram_dry_air")])

    // strings
    verifyToks(Str<|""|>,  Obj?[Token.val, ""])
    verifyToks(Str<|"x y"|>,  Obj?[Token.val, "x y"])
    verifyToks(Str<|"x\"y"|>,  Obj?[Token.val, "x\"y"])
    verifyToks(Str<|"_\u012f \n \t \\_"|>,  Obj?[Token.val, "_\u012f \n \t \\_"])

    // triple quoted strings
    verifyToks(Str<|""""""|>,  Obj?[Token.val, ""])
    verifyToks(Str<|"""triple"""|>,  Obj?[Token.val, "triple"])
    verifyToks(Str<|"""triple
                       LINE 2"""|>,  Obj?[Token.val, "triple\nLINE 2"])
    verifyToks(Str<|""" "foo"
                        "bar"
                        "baz" """|>,  Obj?[Token.val, " \"foo\"\n \"bar\"\n \"baz\" "])

    verifyToks(Str<|"""foo


                       bar

                       """|>,  Obj?[Token.val, "foo\n\n\nbar\n\n"])

    // raw strings
    verifyToks(Str<|r""|>,  Obj?[Token.val, ""])
    verifyToks(Str<|r"\n $ \r"|>,  Obj?[Token.val, Str<|\n $ \r|>])

    // date
    verifyToks("2009-10-04", Obj?[Token.val, Date(2009, Month.oct, 4)])

    // time
    verifyToks("8:30", Obj?[Token.val, Time(8, 30)])
    verifyToks("20:15", Obj?[Token.val, Time(20, 15)])
    verifyToks("00:00", Obj?[Token.val, Time(0, 0)])
    verifyToks("01:02:03", Obj?[Token.val, Time(1, 2, 3)])
    verifyToks("23:59:59", Obj?[Token.val, Time(23, 59, 59)])
    verifyToks("12:00:12.345", Obj?[Token.val, Time("12:00:12.345")])

    // uri
    verifyToks(Str<|`http://foo/`|>,  Obj?[Token.val, `http://foo/`])
    verifyToks(Str<|`_ \n \\ \`_`|>,  Obj?[Token.val, `_ \n \\ \`_`])

    // Ref
    verifyErr(SyntaxErr#) { verifyToks("125b780e-0684e169", Obj?[Token.val, Ref("125b780e-0684e169")]) }
    verifyToks("@125b780e-0684e169", Obj?[Token.val, Ref("125b780e-0684e169")])
    verifyToks("@demo:125b780e-0684e169", Obj?[Token.val, Ref("demo:125b780e-0684e169")])

    // keywords
    verifyToks("true",  Obj?[Token.trueKeyword,  null])
    verifyToks("false", Obj?[Token.falseKeyword, null])
    verifyToks("and",   Obj?[Token.andKeyword,   null])
    verifyToks("or",    Obj?[Token.orKeyword,    null])

    // comments
    verifyToks(
      "4 // foo bar
       5",
       Obj?[Token.val, n(4), Token.val, n(5)])
    verifyToks(
      "/*
         444
       */
       +",
       Obj?[Token.plus, null])
    verifyToks(
      "/*
         /* foo */
       */
       *",
       Obj?[Token.star, null])

    // compound
    verifyToks("foo *  barBaz/6",
      Obj?[Token.id, "foo",
           Token.star, null,
           Token.id, "barBaz",
           Token.slash, null,
           Token.val, n(6)])

    // errors
    verifyErr(SyntaxErr#) { verifyToks(Str<|"fo..|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(Str<|`fo..|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(Str<|"\u345x"|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(Str<|"\ua"|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(Str<|"\u234"|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(Str<|"""x|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(Str<|"""x"|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(Str<|"""x""|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks("#", [,]) }
    verifyErr(SyntaxErr#) { verifyToks("4badUnit", [,]) }
    verifyErr(SyntaxErr#) { verifyToks(""" "foo\n   " """, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(""" r"foo\n   " """, [,]) }

    // triple quote leading spaces
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
             """|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
              """|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
               """|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
             x"""|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
              x"""|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
               x"""|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
               """"|>, [,]) }
    verifyErr(SyntaxErr#) { verifyToks(
      Str<|  """foo
                """"|>, [,]) }
  }

  Void verifyToks(Str src, Obj?[] toks)
  {
    acc := Obj?[,]
    t := Tokenizer(Loc.eval, src.in)
    while (true)
    {
      x := t.next
      verifyEq(x, t.tok)
      if (x == Token.eof) break
      acc.add(t.tok).add(t.val)
    }
    verifyEq(acc, toks)
  }

  static Number n(Num val, Obj? unit := null) { HaystackTest.n(val, unit) }
}