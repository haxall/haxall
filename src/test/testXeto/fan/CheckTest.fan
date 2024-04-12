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
    verifyScalar("Number", n(123, "s"),  Str<|quantity:"power"|>, ["Number must be 'power' unit; 's' has quantity of 'time'"])
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
    CheckScalar.check((CSpec)spec, val) |err| { actual.add(err) }
    // echo(actual.join("\n"))
    verifyEq(actual, Str[,].addAll(expect))
  }

}

