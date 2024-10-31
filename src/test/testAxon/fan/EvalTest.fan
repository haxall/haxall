//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Sep 2009  Brian Frank  Creation
//

using haystack
using axon

**
** EvalTest
**
@Js
class EvalTest : AxonTest
{

  Void testLiterals()
  {
    verifyEval("true", true)
    verifyEval("(true)", true)
    verifyEval("false", false)
    verifyEval("null", null)
    verifyEval("5", n(5))
    verifyEval("6.0", n(6f))
    verifyEval("6.2", n(6.2f))
    verifyEval("0xcafe_babe", n(0xcafe_babe))
    verifyEval("hello".toCode, "hello")
    verifyEval("@125fb380-0072e373", Ref("125fb380-0072e373"))
    verifyEval("@demo:125fb380.0072e373", Ref("demo:125fb380.0072e373"))
    verifyEval("^foo:roo_boo", Symbol("foo:roo_boo"))
    verifyEval("7.15625E-4kWh/ft\u00B2", n(7.15625E-4f, "kWh/ft\u00B2"))
    verifyEval("0.5hr", n(0.5f, "hr"))
    verifyEval("3day", n(3, "day"))
    verifyEval("2mo", n(2, "mo"))
    verifyEval("15.2%", n(15.2f, "%"))
    verifyEval("12.50\$", n(12.50f, "USD"))
    verifyEval("123¥", n(123, "JPY"))
    verifyEval("74\u00b0F", n(74, "fahrenheit"))
    verifyEval("1_200_005m\u00B3", n(1_200_005, "cubic_meter"))
    verifyEval("0.3kW/ft\u00B2", n(0.3f, "kilowatts_per_square_foot"))
    verifyEval("1_2J/kg_dry", n(12, "J/kg_dry"))
    verifyEval("2009-10-05", Date("2009-10-05"))
    verifyEval("9:45", Time(9, 45, 0))
    verifyEval("23:00:17", Time(23, 00, 17))
    verifyEval("2012-02", DateSpan.makeMonth(2012, Month.feb))
    verifyEval("12_345_\$/kW", n(12_345, "_\$/kW"))
    verifyEval("12_345_m/%", n(12_345, "_m/%"))

    verifyAst("true", Str<|{type:"literal", val:T}|>)
    verifyAst("123", Str<|{type:"literal", val:123}|>)
    verifyAst("3ft", Str<|{type:"literal", val:3ft}|>)
    verifyAst("\"hello\"", Str<|{type:"literal", val:"hello"}|>)

    verifySyntaxErr("125fb380-0072e373")  // old Ref syntax
    verifySyntaxErr(Str<|"foo|>)
    verifySyntaxErr(Str<|`foo|>)
    verifySyntaxErr(Str<|@|>)
    verifySyntaxErr(Str<|^|>)
  }

  Void testKinds()
  {
    verifyEval("true", true)
    verifyEval("-134", n(-134))
    verifyEval("2.0", n(2f))
    verifyEval("15mph", n(15, "mph"))
    verifyEval(Str<|"hello\nworld"|>, "hello\nworld")
    verifyEval(Str<|`http://skyfoundry.com/`|>, `http://skyfoundry.com/`)
    verifyEval("2010-03-22", Date(2010, Month.mar, 22))
    verifyEval("6:30:21", Time(6, 30, 21))

    verifyErr(NotHaystackErr#) { Kind.fromVal(3) }
    verifyErr(NotHaystackErr#) { Kind.fromVal(3f) }
    verifyErr(NotHaystackErr#) { Kind.fromVal(3sec) }
  }

  Void testAssign()
  {
    verifyBlock(
      """x: 4
         x = x + 1""", n(5))

    verifyBlock(
      """x: 4
         y: 6
         y = x = x + y
         [x, y]""", Obj?[n(10), n(10)])

    verifyBlock(
      """f: (a, b: null) => do
           if (b == null)
             b = if (isMetric(a)) 4Δ°C else 8Δ°F
           b
         end
         [f(1°F), f(2°C)]""", Obj?[n(8, "Δ°F"), n(4, "Δ°C")])

    verifyBlock(
      """f: (x) => x+1
         a: f(10)
         f = (x) => x+2
         b: f(10)
         [a, b]""", Obj?[n(11), n(12)])

    verifyAst("x: 123", Str<|{type:"def", name:"x", val:{type:"literal", val:123}}|>)
  }

  Void testCond()
  {
    verifyEval("not false", true)
    verifyEval("(not true)", false)
    verifyEval("false and false", false)
    verifyEval("false and true",  false)
    verifyEval("true and false",  false)
    verifyEval("(true and true)",   true)

    verifyEval("false or false", false)
    verifyEval("false or true",  true)
    verifyEval("true or false",  true)
    verifyEval("true or true",   true)

    verifyEval("2 < 3 and 3 == 4", false)
    verifyEval("(2 < 3 or 3 == 4)", true)

    verifyAst("not x", Str<|{type:"not", operand:{type:"var", name:"x"}}|>)
    verifyAst("x and y", Str<|{type:"and", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)

    verifyErr(EvalErr#) { eval("true and \"foo\"") }
    verifyErr(EvalErr#) { eval("false or \"foo\"") }
    verifyErr(EvalErr#) { eval("true and 1") }
    verifyErr(EvalErr#) { eval("false or 1") }
  }

  Void testCompareOps()
  {
    verifyEval("3 == 2", false); verifyEval("3 == 3", true)
    verifyEval("3 != 2", true);  verifyEval("3 != 3", false)
    verifyEval("3 < 2", false);  verifyEval("3 < 3", false); verifyEval("3 < 7", true)
    verifyEval("3 <= 2", false); verifyEval("3 <= 3", true); verifyEval("3 <= 7", true)
    verifyEval("3 > 2", true);   verifyEval("3 > 3", false); verifyEval("3 > 7", false)
    verifyEval("(3 >= 2)", true);  verifyEval("3 >= 3", true); verifyEval("3 >= 7", false)
    verifyEval("(3.0 >= 2)", true)
    verifyEval("(3 >= 10.0)", false)
    verifyEval("(3 <=> 10.0)", n(-1))
    verifyEval("(3 <=> 3.0)", n(0))
    verifyEval("(3.0 <=> 2)", n(1))

    verifyEval("(2.4 == 2.4)", true)
    verifyEval("(3 == 2)", false)
    verifyEval("(12m == 12m)", true)
    verifyEval("(12m == 12)", true)
    verifyEval("(12 == 12ft)", true)
    verifyEval("(12m == 12ft)", false)
    verifyEval("(2 == null)", false)
    verifyEval("(null == null)", true)
    verifyEval("(na() == na())", true)
    verifyEval("(na() != na())", false)
    verifyEval("(na() == null)", false)
    verifyEval("(2.4 == na())", false)

    verifyEval("(12 != 12)", false)
    verifyEval("(3 != 2)", true)
    verifyEval("(12m != 12m)", false)
    verifyEval("(12m != 12)", false)
    verifyEval("(12 != 12ft)", false)
    verifyEval("(12m != 12ft)", true)
    verifyEval("(null != 3)", true)
    verifyEval("(null != null)", false)

    verifyEval("(2 < null)", false)
    verifyEval("(null <= 2)", true)
    verifyEval("(null >= 2)", false)
    verifyEval("(2 >= null)", true)
    verifyEval("(null < na())", true)
    verifyEval("(null <= na())", true)
    verifyEval("(null > na())", false)
    verifyEval("(null >= na())", false)
    verifyEval("(null <=> null)", n(0))
    verifyEval("(3.0 <=> null)", n(1))
    verifyEval("(null <=> 3.0)", n(-1))

    verifyEval(Str<|"foo" < "bar"|>, false)
    verifyEval(Str<|"foo" > "bar"|>, true)
    verifyEval(Str<|"foo" <=> "bar"|>, n(1))
    verifyEval(Str<|"bar" <=> "foo"|>, n(-1))
    verifyEval(Str<|"bar" <=> "bar"|>, n(0))

    // symbols have different subclasses
    verifyEval("(^alpha < ^alpha-beta)", true)
    verifyEval("(^alpha-beta >= ^alpha)", true)
    verifyEval("(^alpha <=> ^alpha)", n(0))
    verifyEval("(^alpha <=> ^alpha-beta)", n(-1))

    verifyEval("(2000ms < 1sec)", false)
    verifyEval("(2000ms < 3sec)", true)
    verifyEval("(3600sec < 1hr)", false)
    verifyEval("(3600sec <= 1hr)", true)

    verifyAst("x < y",  Str<|{type:"lt", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)
    verifyAst("x <= y", Str<|{type:"le", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)
    verifyAst("x == y", Str<|{type:"eq", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)

    verifyEval("(4m < 3m)", false)
    verifyEval("(4m < 3)", false)
    verifyEval("(4 > 3m)", true)
    verifyErr(EvalErr#) { eval("4m < 3km") }
    verifyErr(EvalErr#) { eval("4m <= 3km") }
    verifyErr(EvalErr#) { eval("4m > 3kg") }
    verifyErr(EvalErr#) { eval("4m >= 3kg") }

    verifyErr(EvalErr#) { eval("na() < 3") }
    verifyErr(EvalErr#) { eval("3 > na()") }
    verifyErr(EvalErr#) { eval("3 <=> na()") }
    verifyErr(EvalErr#) { eval("na() <=> true") }
    verifyErr(EvalErr#) { eval("3 <= `foo`") }
    verifyErr(EvalErr#) { eval("`foo` >= 3") }
    verifyErr(EvalErr#) { eval("marker() <= 3") }
    verifyErr(EvalErr#) { eval("({}) >= ({foo})") }
    verifyErr(EvalErr#) { eval("({}.toGrid) >= ({foo}.toGrid)") }
    verifyErr(EvalErr#) { eval(Str<|"a,b".split(",") < "a,b".split(",")|>) }
  }

  Void testMathOps()
  {
    // various spacing of - and +
    verifyBlock("do x: 4; x; end", n(4))
    verifyBlock("do x: 4; -x; end", n(-4))
    verifyBlock("do x: 4; - x; end", n(-4))
    verifyBlock("do x: 4; x-1; end", n(3))
    verifyBlock("do x: 4; x -2; end", n(2))
    verifyBlock("do x: 4; x - 3; end", n(1))
    verifyBlock("do x: 4; x+1; end", n(5))
    verifyBlock("do x: 4; x +2; end", n(6))
    verifyBlock("do x: 4; x + 3; end", n(7))

    verifyEval("-2", n(-2))
    verifyEval("- 3m", n(-3, "m"))
    verifyEval("-(2.0)", n(-2f))
    verifyEval("-null", null)
    verifyEval("-(2L)", n(-2, "liter"))
    verifyEval("-na()", NA.val)
    verifyBlock("do x: na(); -x; end", NA.val)

    verifyEval("2+4", n(6))
    verifyEval("2+4.0", n(6))
    verifyEval("2.0+4", n(6))
    verifyEval("2.0+4.0", n(6))
    verifyEval("2 + -5", n(-3))
    verifyEval("3+null", null)
    verifyEval("null+4.0", null)
    verifyEval("null+null", null)
    verifyEval(Str<|"foo "+null|>, "foo null")
    verifyEval(Str<|null + " foo"|>, "null foo")
    verifyEval("null + na()", null)
    verifyEval("na() + null", null)
    verifyEval("2+na()", NA.val)
    verifyEval("na()+2", NA.val)
    verifyEval("2.0+na()", NA.val)
    verifyEval("na()+2.0", NA.val)
    verifyEval("na()+na()", NA.val)
    verifyEval(Str<|"foo " + na()|>, "foo NA")
    verifyEval(Str<|na() + " foo"|>, "NA foo")

    verifyEval("5 - 3", n(2))
    verifyEval("5 - 3.0", n(2))
    verifyEval("5.0 - 3.0", n(2))
    verifyEval("5.0 - null", null)
    verifyEval("null - 2", null)
    verifyEval("null - null", null)
    verifyEval("null - na()", null)
    verifyEval("na() - null", null)
    verifyEval("na() - 1.0", NA.val)
    verifyEval("1 - na()", NA.val)
    verifyEval("na() - na()", NA.val)

    verifyEval("(5*3)", n(15))
    verifyEval("(5.0*3)", n(15))
    verifyEval("(5*3.0)", n(15))
    verifyEval("(5.0*3.0)", n(15))
    verifyEval("(5.0*null)", null)
    verifyEval("(null*2)", null)
    verifyEval("(null*null)", null)
    verifyEval("null*na()", null)
    verifyEval("na()*null", null)
    verifyEval("1.0*na()", NA.val)
    verifyEval("na()*1", NA.val)
    verifyEval("na()*na()", NA.val)

    verifyEval("15 / 3", n(5))
    verifyEval("15.0 / 3.0", n(5))
    verifyEval("null / 3.0", null)
    verifyEval("2 / null", null)
    verifyEval("null / null", null)
    verifyEval("null / na()", null)
    verifyEval("na() / null", null)
    verifyEval("na() / 1", NA.val)
    verifyEval("1 / na()", NA.val)
    verifyEval("na() / na()", NA.val)

    verifyEval("2+5*3", n(17))
    verifyEval("10 / 2+3*5", n(20))
    verifyEval("10 / (2.0+3)*5", n(10))

    verifyEval("10sec + 50sec", n(60, "s"))
    verifyEval("1min - 3min", n(-2, "min"))
    verifyEval("3in * 4in", n(12, "square_inch"))
    verifyEval("30cubic_meter / 3m", n(10, "square_meter"))

    verifyEval(Str<|"foo" + 5|>, "foo5")
    verifyEval(Str<|5 + "foo"|>, "5foo")
    verifyEval(Str<|"a" + "b" + "c"|>, "abc")

    verifyEval(Str<|`foo/` + "file.txt"|>,       `foo/file.txt`)
    verifyEval(Str<|`foo/bar/` + "../file.txt"|>, `foo/file.txt`)
    verifyEval(Str<|`foo/bar/` + `../file.txt`|>, `foo/file.txt`)
    verifyEval(Str<|`foo/bar/` + `/file.txt`|>,   `/file.txt`)

    verifyEval("12345ms / 2", n(6172.5f, "ms"))
    verifyEval("140sec / 2.5", n(56, "sec"))
    verifyEval("1day * 8", n(8, "day"))
    verifyEval("6day * 0.5", n(3, "day"))
    verifyEval("4ft + 2ft", n(6, "ft"))
    verifyEval("4ft + 2", n(6, "ft"))
    verifyEval("4 + 2ft", n(6, "ft"))
    verifyEval("5ft - 2ft", n(3, "ft"))
    verifyEval("5ft - 2", n(3, "ft"))

    verifyAst("x + y",  Str<|{type:"add", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)
    verifyAst("x - y",  Str<|{type:"sub", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)
    verifyAst("x * y",  Str<|{type:"mul", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)
    verifyAst("x / y",  Str<|{type:"div", lhs:{type:"var", name:"x"}, rhs:{type:"var", name:"y"}}|>)

    verifyErr(EvalErr#) { eval("5ft + 2m") }
    verifyErr(EvalErr#) { eval("5ft - 2in") }
    verifyErr(EvalErr#) { eval("15\u00b0F + 15\u00b0C") }
    verifyErr(EvalErr#) { eval("15\u00b0F - 15\u00b0C") }
  }

  Void testIf()
  {
    verifyEval("if (true) 4", n(4))
    verifyEval("if (false) 4", null)
    verifyEval("if (true) 4 else 5", n(4))
    verifyEval("if (false) 4 else 5", n(5))
    verifyEval("if (true) do x: 3; x else do x: 4; x end", n(3))
    verifyEval("if (false) do x: 3; x else do x: 4; x end", n(4))
    verifyEval("2 + (if (true) 3 else 5)", n(5))
    verifyEval("2 + (if (false) 3 else 5)", n(7))

    // with ends
    verifyBlock(
      """f: (i) => do
           if (i <= 2) do
             if (i == 0) do
               return 88
             end
             if (i == 1) do
               a: 3
               b: 4
               a + b
             end else do
               a: 5
               b: 6
               a + b
             end
           end else if (i == 3) do
             a: 10
             b: 20
             a + b
           end else do
             a: 100
             b: 200
             a + b
           end
         end
         [f(0), f(1), f(2), f(3), f(4)]
         """, Obj?[n(88), n(7), n(11), n(30), n(300)])

    // without end else's
    verifyBlock(
      """f: (i) => do
           if (i <= 2) do
             if (i == 0) do
               return 88
             end
             if (i == 1) do
               a: 3
               b: 4
               a + b
             else do
               a: 5
               b: 6
               a + b
             end
           else if (i == 3) do
             a: 10
             b: 20
             a + b
           else do
             a: 100
             b: 200
             a + b
           end
         end
         [f(0), f(1), f(2), f(3), f(4)]
         """, Obj?[n(88), n(7), n(11), n(30), n(300)])

    verifyBlock(
      """f: () => do
           acc: []
           [0, 1, 2, 3].each(i => do
             if (i.isOdd) return null
             x: "foo-"
             acc = acc.add(x+i)
           end)
           acc
         end
         f()
         """, Obj?["foo-0", "foo-2"])

    verifyAst("if (x) 123", Str<|{type:"if", cond:{type:"var", name:"x"}, ifExpr:{type:"literal", val:123}}|>)
    verifyAst("if (x) 123 else 789", Str<|{type:"if", cond:{type:"var", name:"x"}, ifExpr:{type:"literal", val:123}, elseExpr:{type:"literal", val:789}}|>)
  }


  Void testRanges()
  {
    verifyEval("(2..3).start", n(2))
    verifyEval("(2..3).end", n(3)) // end is keyword
    verifyEval("(2..3).core::end", n(3))
    verifyEval("core::end(2..3)", n(3))
    verifyEval("(2..3).toStr", "2..3")
    verifyEval("2..3", ObjRange(n(2), n(3)))
    verifyEval("2 + 3.. 10 + 2", ObjRange(n(5), n(12)))
    verifyEval("2010-01-01..2010-01-03", DateSpan(Date("2010-01-01"), Date("2010-01-03")))
    verifyEval("null..3sec", ObjRange(null, n(3, "sec")))
    verifyEval("null..null", ObjRange(null, null))

    verifyAst("x .. y",  Str<|{type:"range", start:{type:"var", name:"x"}, end:{type:"var", name:"y"}}|>)
  }

  Void testBins()
  {
    verifyEval(Str<|xstr("Bin", "text/plain")|>, Bin("text/plain"))
    verifyEval(Str<|xstr("Bin", "text/plain; charset=utf-8")|>, Bin("text/plain; charset=utf-8"))
  }

  Void testLists()
  {
    verifyEval("[]", Obj?[,])
    verifyEval("[2]", Obj?[n(2)])
    verifyEval("[2kg, 3ft]", Obj?[n(2, "kilogram"), n(3, "foot")])
    verifyEval("[2, 3, ]", Obj?[n(2), n(3)])
    verifyEval(
      "[
        [1, 2, 3],
        [4, 5, 6]
       ]", Obj?[ Obj?[n(1), n(2), n(3)], Obj?[n(4), n(5), n(6)]])

    // const value
    cx := makeContext
    expr := cx.parse("[`foo`, [1, 2], null]")
    verifyEq(expr.isConst, true)
    verifySame(expr.eval(cx), expr.eval(cx))
    verifyEq(expr.eval(cx), [`foo`, Obj?[n(1), n(2)], null])

    verifyAst("[x, y]",  Str<|{type:"list", vals:[{type:"var", name:"x"}, {type:"var", name:"y"}]}|>)

    // errors
    verifySyntaxErr("[")
    verifySyntaxErr("[3")
    verifySyntaxErr("[3,")
  }

  Void testDicts()
  {
    verifyEval("{}", Str:Obj?[:])
    verifyEval("{a:3}", Str:Obj?["a":n(3)])
    verifyEval("{a:3,b,c:5.2m,-foo}", Str:Obj?["a":n(3),"b":Marker.val,"c":n(5.2f, "m"), "foo":Remove.val])
    verifyEval(
      "{
         a:3,
         b,
         c:5.0%
       }", Str:Obj?["a":n(3),"b":Marker.val,"c":n(5, "%")])

    // nested
    Dict d := eval("{list:[1,2], rec:{a}}")
    verifyEq(d->list, Obj?[n(1), n(2)])
    verifyDictEq(d->rec, ["a":Marker.val])

    // str literals
    verifyEval(Str<|{"foo bar", r"\d":123}|>, Str:Obj?["foo bar":Marker.val, "\\d":n(123)])

    // const value
    cx := makeContext
    expr := cx.parse("{a, b:[1, 2], c:{foo}}")
    verifyEq(expr.isConst, true)
    verifySame(expr.eval(cx), expr.eval(cx))
    verifyDictEq(expr.eval(cx), Etc.makeDict(["a":m, "b":Obj?[n(1), n(2)], "c":Etc.makeDict(["foo"])]))

    verifyAst("{x, y:z}",  Str<|{type:"dict", names:["x", "y"], vals:[{type:"literal", val}, {type:"var", name:"z"}]}|>)

    verifySyntaxErr("{")
    verifySyntaxErr("{id")
    verifySyntaxErr("{id:")
    verifySyntaxErr("{id:3")
    verifySyntaxErr("{id:3,")
    verifySyntaxErr("{id=3}")
    verifySyntaxErr("{-foo:5}")
  }

  Void testBlock()
  {
    verifyBlock(
      "do
         a : 3
         b : 4; a + b
       end",
       n(7))

    verifyBlock(
      "do a : 3; b : 4; a + b; end",
       n(7))

    verifyBlock(
      "a: () => do
         z: 4
         temp: do foo: z; foo * foo end
         temp
       end
       b: (x, y) => do
         z: x + y
         z
       end
       a() + b(10, 3)",
       n(29))

    verifyBlock(
      "a: () => do
         // cool eh?
         x: 3

           /* comment */

         y: 4
         z: () =>
             5  // five

         x + y + z()
       end
       a()",
       n(12))

    verifyBlock(
      "do
         a:
            [10, 20, 30]
         a  [2]
       end",
       n(30))

    verifyBlock(
      "do
         a:
            () => 99
         a  ()
       end",
       n(99))

    verifyAst("do x; y; end",  Str<|{type:"block", exprs:[{type:"var", name:"x"}, {type:"var", name:"y"}]}|>)
  }

  Void testCalls()
  {
    verifyBlock("date(2012, 10, 31)", Date("2012-10-31"))
    verifyBlock("date(2012, 10, 31, -99)", Date("2012-10-31"))
    verifyBlock("2012.date(10, 31)", Date("2012-10-31"))
    verifyBlock("2012.date(10, 31, `ignore`, `me`)", Date("2012-10-31"))

    verifyAst("foo(x, y)",  Str<|{type:"call", func:{type:"var", name:"foo"}, args:[{type:"var", name:"x"}, {type:"var", name:"y"}]}|>)
    verifyAst("foo.bar(x, y)",  Str<|{type:"dotCall", func:{type:"var", name:"bar"}, args:[{type:"var", name:"foo"}, {type:"var", name:"x"}, {type:"var", name:"y"}]}|>)
  }

  Void testLambda()
  {
    verifyBlock(
      "three: () => 3.0
       three()",
       n(3))

    verifyBlock(
      "incr: x => x+1
       incr(-8)",
       n(-7))

    verifyBlock(
      "incr: (x) =>
         sum: x+1
         sum
       incr(88)",
       n(89))


    verifyBlock(
      "sum: (x, y) => x + y
       sum(5, 6)",
       n(11))

    verifyBlock(
      "sum: (x, y, z) => x + y + z
       sum(5, 6, 7)",
       n(18))

    verifyBlock(
      "f: (x: 3) => x
       [f(), f(7)]",
       Obj?[n(3), n(7)])

    verifyBlock(
      "f: (x: 3, y:null) => [x,y]
       [f(), f(7), f(8,9)]",
       Obj?[Obj?[n(3),null], Obj?[n(7),null], Obj?[n(8), n(9)]])

    verifyBlock(
      "f: (x, y:4, z:5) => [x,y,z]
       [f(7), f(7,8), f(7,8,9)]",
       Obj?[Obj?[n(7),n(4),n(5)], Obj?[n(7),n(8),n(5)], Obj?[n(7), n(8), n(9)]])

    verifyBlock(
      Str<|f: (x: [7], y: {x:9}) => [x.first, y->x]
           [f(), f([2]), f([2], {x:1, y:2})]
           |>,
       Obj?[Obj?[n(7),n(9)], Obj?[n(2),n(9)], Obj?[n(2),n(1)]])

    verifyAst("(x) => 123",  Str<|{type:"func", params:[{name:"x"}], body:{type:"literal", val:123}}|>)
    verifyAst("(x: null) => 123",  Str<|{type:"func", params:[{name:"x", def:{type:"literal", val:N}}], body:{type:"literal", val:123}}|>)

     verifyEvalErr("((x) => [x,y])()", null)
     verifyEvalErr("((x, y) => [x,y])(3)", null)
     verifyEvalErr("((x, y:4) => [x,y])()", null)

    // not lambdas
    verifyBlock(
      "x: 3
       (x)",
       n(3))

    // not lambdas
    verifyBlock(
      "x: () => 3
       (x())",
       n(3))

    // not lambdas
    verifyBlock(
      "x: 3
       (x == 3)",
       true)

    verifyEval("((x,y)=>x+y)(3,4)", n(7))
    verifyBlock(
      "f: (x,y)=>x+y
       (f(_,4))(5)",
       n(9))

    // verify call ( on same line
    verifySyntaxErr(
      """do
           f: () => "foo"
           3.f
           ()
         end""")
    verifySyntaxErr(
      """do
           f: () => "foo"
           f
           ()
         end""")
  }

  Void testPartialCalls()
  {
    verifyBlock(
      "f: (x) => [x]
       g: f(_)
       g(4)",
       Obj?[n(4)])

    verifyBlock(
      "f:(a, b, c, d) => [a, b, c, d]
       g:f(0, _, 2, _)
       g(1, 3)",
       Obj?[n(0), n(1), n(2), n(3)])

    verifyBlock(
      "foo: 13
       f: (x, y) => x + y
       g: f(_, foo)
       foo = 15
       h: f(_, foo)
       [g(1), h(2)]
       ",
       Obj?[n(14), n(17)])

    verifyBlock(
      "list: [1, 2, 3]
       f: list.map(_)
       f(x => x + 10)
       ",
       Obj?[n(11), n(12), n(13)])

    verifyBlock(
      Str<|list: ["a"]
           dict: {x:"b"}
           grid: toGrid([{y:"c"}])
           f: (foo, l, d, g) => l[0] + "," + d->x + "," + g[0]->y
           g: f(_, list, dict, grid)
           g("ignored")
           |>,
       "a,b,c")

    verifyAst("f(_, 123, _)",  Str<|{type:"partialCall", func:{type:"var", name:"f"}, args:[N, {type:"literal", val:123}, N]}|>)
  }

  Void testTrailingLambda()
  {
    verifyBlock(
      """f: (x) => x()
         g: (a, b, x) => x(a, b)
         r1: f(() => 7)
         r2: f() () => 7
         r3: g(2, 3, (x, y) => x + y)
         r4: g(2, 3) (x, y) => x + y
         r5: g(2, 5) (x, y) => do
           x + y
         end
         [r1, r2, r3, r4, r5]""",
      Obj?[n(7), n(7), n(5), n(5), n(7)])

    verifyEval("""[2, 3, 4, 1, 5].sort((x, y) => -(x <=> y))""",  Obj?[n(5), n(4), n(3), n(2), n(1)])
    verifyEval("""[2, 3, 4, 1, 5].sort() (x, y) => -(x <=> y)""", Obj?[n(5), n(4), n(3), n(2), n(1)])
    verifyEval("""[1, 2, 3].map x => -x""", Obj?[n(-1), n(-2), n(-3)])

    verifyBlock(
      """f: (list, cond) =>
           if (cond) list.findAll x => x.isEven
           else list.findAll x => x.isOdd
         list: [1, 2, 3, 4]
         [f(list, true), f(list, false)]""",
       Obj?[Obj?[n(2), n(4)], Obj?[n(1), n(3)]])
  }

  Void testReturn()
  {
    verifyBlock("return 3", n(3))
    verifyBlock("a: 3; return a; 9", n(3))
    verifyBlock(
      "do
         if (true)
           return 3
         else
           return 4
       end", n(3))
    verifyBlock(
      "do
         if (false)
           return 3
         else
           return 4
       end", n(4))

    verifyBlock(
      "do
         f: (i) => do
           if (i == 0) return 100
           x: i + 1
           if (i == 1) return 101
           x
         end
         return [f(0), f(1), f(2)]
       end", Obj?[n(100), n(101), n(3)])

    verifyAst("return x",  Str<|{type:"return", expr:{type:"var", name:"x"}}|>)

    // verify return expr on same line
    verifySyntaxErr(
      """do
           return
           "ok"
         end""")
  }

  Void testThrow()
  {
    verifyThrow(Str<|throw "this is bad!"|>, ["dis":"this is bad!"])
    verifyThrow(Str<|throw {dis:"bad!", bad, count:3}|>, ["dis":"bad!", "bad":Marker.val, "count":n(3)])
    verifyThrow(Str<|throw null|>, ["dis":"null"])
    verifyThrow(Str<|throw -1972|>, ["dis":"-1972"])
    verifyThrow(Str<|throw {}|>, ["dis":"null"])
    verifyThrow(Str<|throw {foo}|>, ["dis":"null", "foo":Marker.val])
    verifyErr(ThrowErr#) { verifyEval("2 + (throw {foo})", ["dis":"null", "foo":Marker.val]) }

    verifyAst("throw x",  Str<|{type:"throw", expr:{type:"var", name:"x"}}|>)

    // verify throw expr on same line
    verifySyntaxErr(
      """do
           throw
             "err"
         end""")

    try
    {
      eval(Str<|throw {dis:"bad!", bad, count:3}|>)
      fail
    }
    catch (ThrowErr e)
    {
      verifyDictEq(Etc.toErrMeta(e), ["dis":e.toStr, "bad":Marker.val, "count":n(3),
        "errType":"axon::ThrowErr", "errTrace":e.traceToStr, "err":m])
    }
  }

  Void verifyThrow(Str src, Str:Obj expected)
  {
    try
    {
      eval(src)
      fail("No exception thrown: $src")
    }
    catch (ThrowErr e)
    {
      // e.trace
      verifyEq(e.tags["err"], Marker.val)
      verifyEq(e.tags.has("dis"), true)
      expected.each |v, n| { verifyEq(e.tags[n], v) }
    }
  }

  Void testTryCatch()
  {
    verifyEval(Str<|try "ok" catch "err"|>, "ok")
    verifyEval(Str<|try throw "bam!" catch "err"|>, "err")
    verifyEval(Str<|try throw "bam!" catch (3+4)|>, n(7))
    verifyBlock(Str<|x: 4; try throw "bam!" catch (x+2)|>, n(6))
    verifyEval(Str<|try "ok" catch (e) e->dis|>, "ok")
    verifyEval(Str<|try throw "bam!" catch (e) e->dis|>, "bam!")
    verifyEval(Str<|try return "good" catch (e) "bad"|>, "good")
    verifyThrow(Str<|try throw {dis:"foo", bar:today()} catch (e) throw e|>, ["dis":"foo", "bar":Date.today])
    verifyEval("2 + (try 3 catch (e) 5)", n(5))
    verifyEval("2 + (try throw {} catch (e) 5)", n(7))

    verifyAst("try x catch y",  Str<|{type:"try", tryExpr:{type:"var", name:"x"}, catchExpr:{type:"var", name:"y"}}|>)
    verifyAst("try x catch (err) y",  Str<|{type:"try", tryExpr:{type:"var", name:"x"}, errVarName:"err", catchExpr:{type:"var", name:"y"}}|>)


    // with explicit end
    verifyBlock(
      Str<|err: "not used"
           try do
             "hi"
             throw {dis:"bam!", x:3, y:5}
           end catch (err) do
             //echo(err)
             err->x + err->y
           end|>, n(8))

    // without explicit end
    verifyBlock(
      Str<|err: "not used"
           try do
             "hi"
             throw {dis:"bam!", x:3, y:5}
           catch (err) do
             //echo(err)
             err->x + err->y
           end|>, n(8))
  }

  Void testDefcomp()
  {
    // simple comp
    src :=
      Str<|defcomp
             a: {foo, defVal:2}
             b: {bar:123, defVal:3}
             c: {dict:{foo:"bar", list:[1, 2]}}
             d: {neg: -123% }
             do
               c = a + b
               fn1: () => d = a * 2
               fn1()
             end
           end|>
    def := (CompDef)Parser(Loc("foo"), src.in).parseTop("foo")

    // verify print round trips correctly
    p := Printer()
    def.print(p)
    src = p.toStr
    def = (CompDef)Parser(Loc("foo"), src.in).parseTop("foo")

    // test basics
    verifyEq(def.size, 4)
    verifyEq(def.cells[0].name, "a"); verifyDictEq(def.cells[0], ["foo":m, "defVal":n(2)])
    verifyEq(def.cells[1].name, "b"); verifyDictEq(def.cells[1], ["bar":n(123), "defVal":n(3)])
    verifyEq(def.cells[2].name, "c"); verifyDictEq(def.cells[2], ["dict":Etc.makeDict(["foo":"bar", "list":Obj?[n(1), n(2)]])])
    verifyEq(def.cells[3].name, "d"); verifyDictEq(def.cells[3], ["neg":n(-123, "%")])

    comp := def.instantiate.recompute(makeContext)
    verifyEq(comp.get("c"), n(5))
    verifyEq(comp.get("d"), n(4))
  }

  Void verifyBlock(Str src, Obj expected)
  {
    wrapper := "do\n"
    src.splitLines.each |line| { wrapper += "  " + line + "\n" }
    wrapper += "end"
    verifyEval(wrapper, expected)
  }

  Void verifySyntaxErr(Str src)
  {
    verifyErr(SyntaxErr#) { Parser(Loc.eval, src.in).parse }
    verifyErr(SyntaxErr#) { Parser(Loc.eval, (src+"\n").in).parse }
  }

  Void verifyAst(Str src, Str zinc)
  {
    flexList = true
    expr := Parser(Loc("foo"), src.in).parse
    // echo(":: $expr.encode")
    // echo("   $zinc")
    verifyDictEq(expr.encode, ZincReader(zinc.in).readVal)
    flexList = false
  }

  override Void verifyListEq(List a, List b, Str? msg := null)
  {
    if (flexList)
    {
      verifyEq(a.size, b.size)
      a.each |v, i| { verifyValEq(v, b[i], msg) }
    }
    else
    {
      super.verifyListEq(a, b, msg)
    }
  }

  private Bool flexList := false

//////////////////////////////////////////////////////////////////////////
// Parser Func Nesting
//////////////////////////////////////////////////////////////////////////

  Void testFuncNesting()
  {
    src :=
      Str<|(list) => do
             b: (p1, p2) => do
               c: () => null
               d: () => do map(list, a => a); end
               e: b(_, 2)
             end
             map(list, a => a)
           end|>
    loc := Loc("foo")
    tags := Etc.makeDict(["name":"a", "func":Marker.val])
    Fn a := Parser(loc, src.in).parseTop("a")
    Fn b := a.body->exprs->get(0)->val
    Fn c := b.body->exprs->get(0)->val
    Fn d := b.body->exprs->get(1)->val
    PartialCall e := b.body->exprs->get(2)->val  // name will be toStr
    Fn x := d.body->exprs->get(0)->args->get(1)
    Fn y := a.body->exprs->get(1)->args->get(1)

    verifyEq(a.name, "a");            verifySame(a.outer, null)
    verifyEq(b.name, "a.b");          verifySame(b.outer, a)
    verifyEq(c.name, "a.b.c");        verifySame(c.outer, b)
    verifyEq(d.name, "a.b.d");        verifySame(d.outer, b)
    verifyEq(x.name, "a.b.d.anon-1"); verifySame(x.outer, d)
    verifyEq(y.name, "a.anon-2");     verifySame(y.outer, a)
  }

}

