//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using axon

**
** SwitchTest tests switch pattern matching
**
class SwitchTest : AxonTest
{

//////////////////////////////////////////////////////////////////////////
// Literals
//////////////////////////////////////////////////////////////////////////

  Void testLiterals()
  {
    src :=
      Str<|switch (x)
             case 200 => "ok"
             case 404 => "not found"
             case "foo" => "str"
             case -1 => "neg"
             case true => "true"
             case null => "null"
             case 2026-10-30 => "date"
             case @abc => "ref"
             default => "other"
           end|>
    verifySwitch(src, "200", "ok")
    verifySwitch(src, "404", "not found")
    verifySwitch(src, "\"foo\"", "str")
    verifySwitch(src, "\"bar\"", "other")
    verifySwitch(src, "-1", "neg")
    verifySwitch(src, "true", "true")
    verifySwitch(src, "false", "other")
    verifySwitch(src, "null", "null")
    verifySwitch(src, "2026-10-30", "date")
    verifySwitch(src, "@abc", "ref")
    verifySwitch(src, "500", "other")

    // first match wins
    verifySwitch("switch (x) case 1 => \"a\"; case 1 => \"b\" end", "1", "a")

    // Axon equality: unitless literal matches any unit
    verifySwitch("switch (x) case 72 => 1 default => 2 end", "72°F", n(1))
    verifySwitch("switch (x) case 72°C => 1 default => 2 end", "72°F", n(2))
    verifySwitch("switch (x) case 72°F => 1 default => 2 end", "72", n(1))
  }

//////////////////////////////////////////////////////////////////////////
// Default
//////////////////////////////////////////////////////////////////////////

  Void testDefault()
  {
    // no match without default evaluates to null like if without else
    verifySwitch("switch (x) case 4 => 5 end", "3", null)
    verifySwitch("switch (x) end", "3", null)

    // only default
    verifySwitch("switch (x) default => 7 end", "3", n(7))

    // subject evaluated once
    verifyEval(Str<|do
                      n: 0
                      switch (do n = n + 1; n end)
                        case 2 => "two"
                        case 1 => "one"
                      end
                      n
                    end|>, n(1))
  }

//////////////////////////////////////////////////////////////////////////
// Bodies
//////////////////////////////////////////////////////////////////////////

  Void testBodies()
  {
    // do block bodies
    verifyEval(Str<|switch (2)
                      case 1 => do
                        a: 10
                        a + 1
                      end
                      case 2 => do
                        b: 20
                        b + 2
                      end
                    end|>, n(22))

    // switch is an expr; like if it must be grouped inside an operator
    verifyEval(Str<|"x" + (switch (1) case 1 => "y" end) + "z"|>, "xyz")
    verifyEval(Str<|[switch (1) case 1 => "y" end, 2]|>, Obj?["y", n(2)])

    // return in body exits enclosing func
    f := Str<|(x) => do
                switch (x)
                  case 1 => return "early"
                end
                "late"
              end|>
    verifyEq(makeContext.evalToFunc(f).call(makeContext, [n(1)]), "early")
    verifyEq(makeContext.evalToFunc(f).call(makeContext, [n(2)]), "late")

    // body can assign outer var
    verifyEval(Str<|do
                      t: 0
                      switch (3) case 3 => t = 9 end
                      t
                    end|>, n(9))

    // nested switch
    verifyEval(Str<|switch (1)
                      case 1 => switch (2)
                        case 2 => "inner"
                      end
                    end|>, "inner")
  }

//////////////////////////////////////////////////////////////////////////
// Errors
//////////////////////////////////////////////////////////////////////////

  Void testErrors()
  {
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 => 2") }
    verifyErr(SyntaxErr#) { eval("switch (1) case foo => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 + 2 => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) case 1 2 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) default => 1 case 2 => 3 end") }
    verifyErr(SyntaxErr#) { eval("switch (1) default => 1 default => 2 end") }
    verifyErr(SyntaxErr#) { eval("switch 1 case 1 => 2 end") }
  }

//////////////////////////////////////////////////////////////////////////
// AST
//////////////////////////////////////////////////////////////////////////

  Void testAst()
  {
    src :=
      Str<|switch (x)
             case 200 => 1
             case "a" => 2
             default => 3
           end|>
    expr := Parser(src.in).parse

    // print round trips
    str := expr.toStr
    verifyEq(Parser(str.in).parse.toStr, str)

    // encode
    ast := expr.encode
    verifyEq(ast->type, "switch")
    Dict[] cases := ast->cases
    verifyEq(cases.map |c->Obj?| { c->type }, Obj?["switchCase", "switchCase"])
    verifyEq(cases.map |c->Obj?| { c->pattern->type }, Obj?["literalPattern", "literalPattern"])
    verifyEq(cases.map |c->Obj?| { c->pattern->val }, Obj?[n(200), "a"])
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Eval switch src with variable x bound to subject src
  Void verifySwitch(Str src, Str subject, Obj? expected)
  {
    verifyEval("do x: $subject\n$src\nend", expected)
  }
}
