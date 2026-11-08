//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using axon

**
** ParseTest
**
@Js
class ParseTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Expr
//////////////////////////////////////////////////////////////////////////

  Void testExpr()
  {
    verifyExpr("x")
    verifyExpr("x + y")
    verifyExpr("(x + y) * 123")

    verifyExprErr("x.")
    verifyExprErr("x x")
  }

  Void testNullSafe()
  {
    verifyExpr("a?.foo()")
    verifyExpr("a?.foo(b, c)")
    verifyExpr("(a?.foo()).bar()")
    verifyExpr("(a.foo())?.bar()")
    verifyExpr("a?->foo")
    verifyExpr("a?->foo->bar")
    verifyExpr("a?.map((x) => x)")
    verifyEq(Parser("a?.foo".in).parse.toStr, "a?.foo()")
    verifyEq(Parser("list?.map x => x".in).parse.toStr, "list?.map((x) => x)")
    verifyEq(Parser("a\n  ?.foo".in).parse.toStr, "a?.foo()")

    verifyExprErr("a?.b = 3")
    verifyExprErr("a?.b::c")
    verifyExprErr("a?.foo(_)")
    verifyExprErr("a?.")
    verifyExprErr("a?->")
  }

  Void testElvis()
  {
    verifyExpr("a ?: b")
    verifyExpr("x = a ?: b")
    verifyExpr("(a or b) ?: c")
    verifyExpr("a ?: (b or c)")
    verifyExpr("a ?: (throw \"x\")")
    verifyEq(Parser("a or b ?: c or d".in).parse.toStr, "(a or b) ?: (c or d)")
    verifyEq(Parser("a ?: throw \"x\"".in).parse.toStr, "a ?: (throw \"x\")")

    verifyExprErr("a ?: b ?: c")
    verifyExprErr("a ?: return b")
    verifyExprErr("a ? b : c")
  }

  Void testLiteralTermBase()
  {
    // list/dict literals can appear as operand of unary and as base of term chain
    verifyParse("not [1, 2, 3].contains(2)")
    verifyParse("[1, 2, 3].size")
    verifyParse("{a, b}.has(\"a\")")
  }

  Void verifyParse(Str s)
  {
    verifyNotNull(Parser(s.in).parse)
  }

  Void verifyExpr(Str s)
  {
    e := Parser(s.in).parse
    verifyEq(e.toStr, s)
  }

  Void verifyExprErr(Str s)
  {
    verifyErr(SyntaxErr#) { Parser(s.in).parse }
  }

//////////////////////////////////////////////////////////////////////////
// Pattern
//////////////////////////////////////////////////////////////////////////

  Void testParsePattern()
  {
    verifyPattern("200", "200")
    verifyPattern("\"foo\"", "\"foo\"")
    verifyPattern("400..499", "400..499")
    verifyPattern("200 or 204", "200 or 204")
    verifyPattern("200 or 204 as code", "200 or 204 as code")
    verifyPattern("Vav {airRef as a, area: Number? as sz} as v", "Vav {airRef as a, area: Number? as sz} as v")

    verifyErr(SyntaxErr#) { Parser("200 =>".in).parsePattern }
    verifyErr(SyntaxErr#) { Parser("x".in).parsePattern }
    verifyErr(SyntaxErr#) { Parser("1 as x as y".in).parsePattern }
    verifyErr(SyntaxErr#) { Parser("{a as x, b as x}".in).parsePattern }
  }

  Void verifyPattern(Str src, Str expect)
  {
    verifyEq(Parser(src.in).parsePattern.toStr, expect)
  }

//////////////////////////////////////////////////////////////////////////
// Pipeline
//////////////////////////////////////////////////////////////////////////

  Void testPipeline()
  {
    verifyPipeline("x", ["x"])
    verifyPipeline("x | y", ["x", "y"])
    verifyPipeline("x | y | z", ["x", "y", "z"])
    verifyPipeline("x | y | z", ["x", "y", "z"])
    verifyPipeline("foo() | bar() | 3 + n", ["foo()", "bar()", "3 + n"])

    verifyPipeline(
      Str<|do
             foo().bar()
             echo(123)
           end | do
             bar()
           end

           |

           do
             baz()
             qux()
           end|>,
          ["do
              (foo()).bar();
              echo(123);
            end",
            "do
               bar();
             end",
             "do
                baz();
                qux();
              end"])


    verifyPipelineErr("x.")
    verifyPipelineErr("x |")
    verifyPipelineErr("x | foo(")
  }

  Void verifyPipeline(Str s, Str[] expect)
  {
    actual := Parser(s.in).parsePipeline
    verifyEq(actual.size, expect.size)
    actual.each |a, i|
    {
      verifyEq(a.toStr.trim, expect[i])
    }
  }

  Void verifyPipelineErr(Str s)
  {
    verifyErr(SyntaxErr#) { verifyPipeline(s, Str[,]) }
  }

//////////////////////////////////////////////////////////////////////////
// Host
//////////////////////////////////////////////////////////////////////////

  Void testHost()
  {
    verifyHost("a {x + 1} b", ["a ", "x + 1", " b"])
    verifyHost("{x}{y}", ["x", "y"])

    // the host tokenizes past the close, so text need not be Axon
    verifyHost(Str<|{x} don't "|>, ["x", Str<| don't "|>])

    // braces inside Axon are Axon's own
    verifyHost(Str<|{{a:1}->a}!|>, ["{a:1}->a", "!"])
    verifyHost(Str<|{"}" + `}`}|>, [Str<|"}" + `}`|>])

    // one line count across both
    exprs := HostParser("a\nb {\n x}").parseHost
    verifyEq(((Expr)exprs[1]).loc.line, 3)
    exprs = HostParser("{\"\"\"\n    ab\n    \"\"\"}\n{x}").parseHost
    verifyEq(((Expr)exprs[2]).loc.line, 4)

    verifyErr(SyntaxErr#) { HostParser("{x").parseHost }
    verifyErr(SyntaxErr#) { HostParser("{x y}").parseHost }
  }

  Void verifyHost(Str src, Str[] expect)
  {
    verifyEq(HostParser(src).parseHost.map |x->Str| { x.toStr }, expect)
  }
}

**************************************************************************
** HostTokenizer
**************************************************************************

** Host language of text with {expr} holes
@Js
internal class HostTokenizer : Tokenizer
{
  new make(Str src) : super(src.in) {}

  override Token next()
  {
    if (inAxon)
    {
      t := super.next
      if (t === Token.lbrace) ++depth
      if (t === Token.rbrace) { if (depth == 0) inAxon = false; else --depth }
      return t
    }
    if (cur == 0) return tok = Token.eof
    if (cur == '{') { consume; inAxon = true; return tok = Token.lbrace }
    buf := StrBuf()
    while (cur != 0 && cur != '{') { buf.addChar(cur); consume }
    val = buf.toStr
    return tok = Token.foreign
  }

  private Bool inAxon
  private Int depth
}

**************************************************************************
** HostParser
**************************************************************************

@Js
internal class HostParser : Parser
{
  new make(Str src) : super.makeTokenizer(HostTokenizer(src)) {}

  ** Text as Str and holes as Expr
  Obj[] parseHost()
  {
    acc := Obj[,]
    while (cur !== Token.eof)
    {
      if (cur === Token.foreign) { acc.add(curVal); consume; continue }
      consume(Token.lbrace)
      acc.add(expr)
      consume(Token.rbrace)
    }
    return acc
  }
}
