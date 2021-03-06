//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Feb 2022  Matthew Giannini  Creation
//

using haystack

internal mixin EcobeeUtil
{
  static const Unit fahr    := Unit.fromStr("fahrenheit")
  static const Unit relHum  := Unit.fromStr("%RH")
  static const Unit sec     := Unit.fromStr("second")

  ** Convert an Ecobee object field to Haystack point type
  static Obj? toHay(Obj? val, Unit? unit := null)
  {
    if (val == null)  return null
    if (val is Float) return Number.make(val, unit)
    if (val is Int)   return Number.makeInt(val, unit)
    if (val is Str)   return val

    // I give up
    return val.toStr
  }

  ** Convert a Haystack value to Ecobee field type
  static Obj? toEcobee(Obj? val, Field field)
  {
    if (val == null) return null
    return val.toStr
  }
}