//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv
using haystack

**
** CheckTest
**
@Js
class CheckTest : AbstractXetoTest
{

  Void testNumbers()
  {
    // no constraints
    verifyScalar("Number", n(123), "", [,])

    // minVal
    verifyScalar("Number", n(123), Str<|minVal:123|>,  [,])
    verifyScalar("Number", n(123), Str<|minVal:124|>,  ["Number 123 < minVal 124"])
    verifyScalar("Number", n(-7),  Str<|minVal:"-6"|>, ["Number -7 < minVal -6"])

    // maxVal
    verifyScalar("Number", n(123), Str<|maxVal:123|>, [,])
    verifyScalar("Number", n(123), Str<|maxVal:122|>, ["Number 123 > maxVal 122"])

    // unit
    verifyScalar("Number", n(123, "kW"), Str<|unit:"kW"|>, [,])
    verifyScalar("Number", n(123),       Str<|unit:"kW"|>, ["Number 123 must have unit of 'kW'"])
    verifyScalar("Number", n(123, "W"),  Str<|unit:"kW"|>, ["Number 123W must have unit of 'kW'"])

    // Quantity
    verifyScalar("Number", n(123, "kW"), Str<|quantity:"power"|>, [,])
    verifyScalar("Number", n(123),       Str<|quantity:"power"|>, ["Number must be 'power' unit; no unit specified"])
    verifyScalar("Number", n(123, "s"),  Str<|quantity:"power"|>, ["Number must be 'power' unit; 'sec' has quantity of 'time'"])
    verifyScalar("Number", n(123, "%"),  Str<|quantity:"power"|>, ["Number must be 'power' unit; '%' has quantity of 'dimensionless'"])
    verifyScalar("Number", n(123, "_x"), Str<|quantity:"power"|>, ["Number must be 'power' unit; '_x' has no quantity"])
  }

  Void verifyScalar(Str type, Obj val, Str meta, Str[] expect)
  {
    src :=
      """Foo: {
           x: $type <$meta>
         }
         """

    ns := sysNamespace
    lib := ns.compileLib(src)
    spec := lib.type("Foo").slot("x")

    actual := Str[,]
    CheckVal(Etc.dict0).check((CSpec)spec, val) |err| { actual.add(err) }
    // echo(actual.join("\n"))
    verifyEq(actual, Str[,].addAll(expect))
  }

//////////////////////////////////////////////////////////////////////////
// Patterns
//////////////////////////////////////////////////////////////////////////

  Void testPatterns()
  {
    verifyPattern("sys::Date", "2024-10-08", true)
    verifyPattern("sys::Date", "2024-10-8",  false)
    verifyPattern("sys::Date", "2024-10-x8", false)
    verifyPattern("sys::Date", "24-10-18",   false)

    verifyPattern("sys::Time", "12:34:54",     true)
    verifyPattern("sys::Time", "12:34:54.123", true)
    verifyPattern("sys::Time", "12:34:54.x",   false)
    verifyPattern("sys::Time", "12:34:5",      false)
    verifyPattern("sys::Time", "12:34:5",      false)
    verifyPattern("sys::Time", "12:34",        false)
    verifyPattern("sys::Time", "12:34:qq",     false)

    verifyPattern("sys::DateTime", "2024-10-29T09:38:21-04:00 New_York",     true)
    verifyPattern("sys::DateTime", "2024-10-29T09:38:21.295-04:00 New_York", true)
    verifyPattern("sys::DateTime", "2024-10-29T09:38:2.295-04:00 New_York",  false)
    verifyPattern("sys::DateTime", "2024-10-29 09:38:22.295-04:00 New_York", false)
    verifyPattern("sys::DateTime", "2024-10-29T9:38:22.295-04:00 New_York",  false)
  }

  Void verifyPattern(Str qname, Str s, Bool expect)
  {
    ns := sysNamespace
    re := Regex(ns.spec(qname).meta->pattern)
    actual := re.matches(s)
    // echo(">> $re $s | $actual ?= $expect")
    verifyEq(actual, expect, s)
  }

}

