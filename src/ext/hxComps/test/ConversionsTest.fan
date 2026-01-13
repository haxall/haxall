//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2025  Matthew Giannini  Creation
//

using xeto
using haystack

class ConversionsTest : HxCompTest
{
  Void testBoolToStatusBool()
  {
    TestHxCompContext().asCur |cx|
    {
      BoolToStatusBool c := createAndExec("BoolToStatusBool")
      verifyEq(c.out, sb(false))
      setAndExec(c,"in", true)
      verifyEq(c.out, sb(true))
      setAndExec(c,"in", false)
      verifyEq(c.out, sb(false))

      c = loadComp(Str<|@a: BoolToStatusBool { in: "true" }|>)
      verifyEq(c.out, sb(true))
    }
  }

  Void testStatusBoolToBool()
  {
    TestHxCompContext().asCur |cx|
    {
      StatusBoolToBool c := createAndExec("StatusBoolToBool")
      verifyEq(c.out, false)
      setAndExec(c,"in", sb(true))
      verifyEq(c.out, true)
      setAndExec(c,"in", sb(true, Status.fault))
      verifyEq(c.out, true)
      setAndExec(c,"in", null)
      verifyEq(c.out, false)
      c.whenNull = true; cs.execute
      verifyEq(c.out, true)

      c = loadComp(Str<|@a: StatusBoolToBool { whenNull: "true" }|>)
      verifyEq(c.out, true)
      c = loadComp(Str<|@a: StatusBoolToBool { in: StatusBool { val: "true" } }|>)
      verifyEq(c.out, true)
    }
  }

  Void testNumberToStatusNumber()
  {
    TestHxCompContext().asCur |cx|
    {
      NumberToStatusNumber c := createAndExec("NumberToStatusNumber")
      verifyEq(c.out, sn(0))
      setAndExec(c,"in", n(100))
      verifyEq(c.out, sn(100))
      setAndExec(c,"in",n(-2.5f, "m"))
      verifyEq(c.out, sn(n(-2.5f, "m")))

      c = loadComp(Str<|@a: NumberToStatusNumber { in: 50ft }|>)
      verifyEq(c.out, sn(n(50, "ft")))
    }
  }

  Void testStatusNumberToNumber()
  {
    TestHxCompContext().asCur |cx|
    {
      StatusNumberToNumber c := createAndExec("StatusNumberToNumber")
      verifyEq(c.out, n(0))
      setAndExec(c,"in", sn(100))
      verifyEq(c.out, n(100))
      setAndExec(c,"in", sn(200, Status.disabled))
      verifyEq(c.out, n(200))
      setAndExec(c,"in", null)
      verifyEq(c.out, n(0))
      c.whenNull = n(50, "ft"); cs.execute
      verifyEq(c.out, n(50, "ft"))

      c = loadComp(Str<|@a: StatusNumberToNumber { whenNull: 100m }|>)
      verifyEq(c.out, n(100,"m"))
      c = loadComp(Str<|@a: StatusNumberToNumber { in: StatusNumber { val: 60ft } }|>)
      verifyEq(c.out, n(60,"ft"))
    }
  }

  Void testStrToStatusStr()
  {
    TestHxCompContext().asCur |cx|
    {
      StrToStatusStr c := createAndExec("StrToStatusStr")
      verifyEq(c.out, ss(""))
      setAndExec(c, "in", "foo")
      verifyEq(c.out, ss("foo"))
      setAndExec(c, "in", "\u{1f60a}")
      verifyEq(c.out, ss("\u{1f60a}"))

      c = loadComp(Str<|@a: StrToStatusStr { in: "xeto" }|>)
      verifyEq(c.out, ss("xeto"))
    }
  }

  Void testStatusStrToStatusNumber()
  {
    TestHxCompContext().asCur |cx|
    {
      StatusStrToStatusNumber c := createAndExec("StatusStrToStatusNumber")
      verifyNull(c.out)
      setAndExec(c, "in", ss("100"))
      verifyEq(c.out, sn(100))
      setAndExec(c,"in", ss("-1.5ft", Status.disabled))
      verifyEq(c.out, sn(n(-1.5f,"ft"), Status.disabled))
      setAndExec(c,"in", ss(""))
      verifyEq(c.out, sn(Number.nan, Status.fault))
      setAndExec(c,"in", ss("nope"))
      verifyEq(c.out, sn(Number.nan, Status.fault))
    }
  }
}