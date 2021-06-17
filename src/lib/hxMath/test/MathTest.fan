//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2010   Brian Frank   Creation
//

using haystack
using hx

**
** MathTest
**
class MathTest : HxTest
{
  @HxRuntimeTest
  Void test()
  {
    rt.libs.add("hxMath")

    // constants
    verifyEq(eval("pi()"), Number(Float.pi))

    // utils
    verifyEq(eval("23.remainder(5)"), n(3f))
    verifyEq(eval("23sec.remainder(5)"), n(3f, "sec"))
    verifyEq(eval("remainder(8.27, 2)")->toFloat->approx(0.27f), true)
    verifyEq(eval("floor(2.4)"), n(2f))
    verifyEq(eval("floor(2.4ft)"), n(2f, "ft"))
    verifyEq(eval("ceil(2.4)"), n(3f))
    verifyEq(eval("ceil(2.4in)"), n(3f, "in"))
    verifyEq(eval("round(2.4)"), n(2f))
    verifyEq(eval("round(2.4\$)"), n(2f, "\$"))
    verifyEq(eval("exp(2)"), n(7.38905609893065f))
    verifyEq(eval("exp(2).logE"), n(2f))
    verifyEq(eval("1000.log10"), n(3f))
    verifyEq(eval("2.pow(8)"), n(256f))
    verifyEq(eval("9.sqrt"), n(3f))

    // random with no range
    acc := Number[,]
    100.times { acc.add(eval("random()")) }
    verifyEq(acc.unique.size, 100)

    // random with range
    acc.clear
    100.times { acc.add(eval("random(0..100)")) }
    verifyEq(acc.all { (0..100).contains(it.toInt) }, true)

    // bitwise
    verifyEq(eval("0xabc07.bitNot"), n(0xabc07.not))
    verifyEq(eval("0x237cafe.bitAnd(0xaf0734)"), n(0x237cafe.and(0xaf0734)))
    verifyEq(eval("bitOr(0x237cafe, 0xaf0734)"), n(0x237cafe.or(0xaf0734)))
    verifyEq(eval("bitXor(0x237cafe, 0xaf0734)"), n(0x237cafe.xor(0xaf0734)))
    verifyEq(eval("bitShiftr(0x237cafe, 4)"), n(0x237caf))
    verifyEq(eval("bitShiftl(0x237cafe, 8)"), n(0x237cafe00))

    // trig
    verifyEq(eval("acos(0.2)"), Number(0.2f.acos))
    verifyEq(eval("asin(0.2)"), Number(0.2f.asin))
    verifyEq(eval("atan(0.2)"), Number(0.2f.atan))
    verifyEq(eval("atan(0.2)"), Number(0.2f.atan))
    verifyEq(eval("atan2(1, 2)"), Number(Float.atan2(1f, 2f)))
    verifyEq(eval("cos(2)"), Number(2f.cos))
    verifyEq(eval("cosh(2)"), Number(2f.cosh))
    verifyEq(eval("sin(2)"), Number(2f.sin))
    verifyEq(eval("sinh(2)"), Number(2f.sinh))
    verifyEq(eval("tan(2)"), Number(2f.tan))
    verifyEq(eval("tanh(2)"), Number(2f.tanh))
    verifyEq(eval("toDegrees(pi())"), Number(180f))
    verifyEq(eval("toRadians(180)"), n(Float.pi))

    // statistics stuff
    verifyStandardDeviation
    verifyFitLinearRegression
  }

  @HxRuntimeTest
  Void testFolds()
  {
    rt.libs.add("hxMath")

    // Test cases for RMSE and MBE provided by PNL

    //           list                       mean          median RMSE-0        RMSE-1        MBE-0          MBE-1
    //           ----------------------     ------------  ------ ------        -------       -----          -----
    verifyFolds("[]",                       null,         null,  null,         null,         null,          null)
    verifyFolds("[na()]",                   NA.val,       NA.val,NA.val,       NA.val,       NA.val,        NA.val)
    verifyFolds("[null]",                   null,         null,  null,         null,         null,          null)
    verifyFolds("[2]",                      2f,           2f,    0f,           null,         0f,            null)
    verifyFolds("[1, 4]",                   2.5f,         2.5f,  1.060660172f, 2.121320344f, 0f,            0f)
    verifyFolds("[4, 2, 7]",                4.333333333f, 4f,    1.201850425f, 1.802775638f, 0.3333333333f, 0.5f)
    verifyFolds("[4, na(), 7]",             NA.val,       NA.val,NA.val,       NA.val,       NA.val,        NA.val)
    verifyFolds("[-3, 4, 10, 11, 6, 4]",    5.333333333f, 5f,    1.885618083f, 2.2627417f,   0.3333333333f, 0.4f)
    verifyFolds("[-3, 4, 10, 2, 11, 6, 2]", 4.57142857f,  4f,    1.726149425f, 2.013840996f, 0.571428571f,  0.666666667f)
  }

  Void verifyFolds(Str list, Obj? mean, Obj? median, Obj? rmse0, Obj? rmse1, Obj? mbe0, Obj? mbe1)
  {
    verifyFoldEq("${list}.fold(mean)", mean)
    verifyFoldEq("${list}.fold(median)", median)
    verifyFoldEq("${list}.fold(rootMeanSquareErr)", rmse0)
    verifyFoldEq("${list}.fold(rootMeanSquareErr(_, _, 1))", rmse1)
    verifyFoldEq("${list}.fold(meanBiasErr)", mbe0)
    verifyFoldEq("${list}.fold(meanBiasErr(_,_,1))", mbe1)
  }

  Void verifyFoldEq(Str axon, Obj? expected)
  {
    Obj? actual := eval(axon)
    if (expected == null) verifyNull(actual)
    else if (expected === NA.val) verifyEq(actual, expected)
    else if (!((Number)actual).toFloat.approx(expected))
      fail("$axon  $expected != $actual")
  }

  Void verifyStandardDeviation()
  {
    verifyFoldEq("[1.21, 3.4, 2, 4.66, 1.5, 5.61, 7.22].fold(standardDeviation)", 2.2718326984f)
    verifyFoldEq("[4, 2, 5, 8, 6].fold(standardDeviation)", 2.23606798f)
    verifyFoldEq("[4, na(), 5, 8, 6].fold(standardDeviation)", NA.val)
  }

  Void verifyFitLinearRegression()
  {
    // test slope and intercept
    Dict r := eval("[{x:0,y:1}, {x:1, y:0}, {x:3,y:2}, {x:5,y:4}, {x:nan(), y:33}].toGrid.fitLinearRegression")
    verifyNumApprox(r->m, 0.694915254f)
    verifyNumApprox(r->b, 0.186440678f)
    verifyEq(r->xmin, n(0))
    verifyEq(r->xmax, n(5))
    verifyEq(r->ymin, n(0))
    verifyEq(r->ymax, n(4))

    // test from Khan Academy example
    r = eval("[{x:-2,y:-3}, {x:-1,y:-1}, {x:1,y:2}, {x:4,y:3}].toGrid.fitLinearRegression")
    verifyNumApprox(r->m, 41f/42f)
    verifyNumApprox(r->b, -5f/21f)
    verifyNumApprox(r->r2, 0.879644165f)
    verifyEq(r->xmin, n(-2))
    verifyEq(r->xmax, n(4))
    verifyEq(r->ymin, n(-3))
    verifyEq(r->ymax, n(3))
  }
}