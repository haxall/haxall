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
// FreeVars
//////////////////////////////////////////////////////////////////////////

  Void testFreeVars()
  {
    // basics
    verifyFreeVars("3 + 4", Str[,])
    verifyFreeVars("x", ["x"])
    verifyFreeVars("x + y * x", ["x", "y"])
    verifyFreeVars("[a, b, a]", ["a", "b"])
    verifyFreeVars("{dis: d, n: 3}", ["d"])
    verifyFreeVars("if (c) a else b", ["c", "a", "b"])
    verifyFreeVars("x = 3", ["x"])
    verifyFreeVars("switch (v) case 1 => a default => b end", ["v", "a", "b"])

    // call position is a func, not a var
    verifyFreeVars("foo(x)", ["x"])
    verifyFreeVars("x.foo", ["x"])
    verifyFreeVars("x.foo(y)", ["x", "y"])
    verifyFreeVars("x->dis", ["x"])
    verifyFreeVars("foo(_, x)", ["x"])
    verifyFreeVars("(x => x)(y)", ["y"])

    // local defs bind after their value
    verifyFreeVars("do a: x; a + b end", ["x", "b"])
    verifyFreeVars("do a: a + 1; a end", ["a"])
    verifyFreeVars("do y; y: 1; y end", ["y"])
    verifyFreeVars("do f: (x) => x; f(y) end", ["y"])

    // func params, including defaults that read earlier params
    verifyFreeVars("x => x", Str[,])
    verifyFreeVars("rows.map(r => r->dis + s)", ["rows", "s"])
    verifyFreeVars("(a, b: a + c) => a + b + d", ["c", "d"])
    verifyFreeVars("(a: b, b: 1) => a", ["b"])
    verifyFreeVars("x => y => x + y + z", ["z"])
    verifyFreeVars("do r: [1].map(x => do v: x; v end); v end", ["v"])

    // catch var
    verifyFreeVars("try foo(x) catch (e) e->dis + y", ["x", "y"])
    verifyFreeVars("try x catch e", ["x", "e"])
  }

  Void verifyFreeVars(Str src, Str[] expect)
  {
    verifyEq(Parser(src.in).parse.freeVars, expect)
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
    dummyTop := TopFn(FileLoc.unknown, "dummy", Etc.dict0, FnParam[,])

    actual := Parser(s.in).parsePipeline(dummyTop)
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
}

