//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2026  Brian Frank  Creation
//

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

  Void verifyExpr(Str s)
  {
    e := Parser(Loc("test"), s.in).parse
    verifyEq(e.toStr, s)
  }

  Void verifyExprErr(Str s)
  {
    verifyErr(SyntaxErr#) { Parser(Loc("test"), s.in).parse }
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
    actual := Parser(Loc("test"), s.in).parsePipeline
    verifyEq(actual.size, expect.size)
    actual.each |a, i|
    {
      verifyEq(a.toStr.trim, expect[i])
    }
  }

  Void verifyPipelineErr(Str s)
  {
    verifyErr(SyntaxErr#) { Parser(Loc("test"), s.in).parsePipeline }
  }
}

