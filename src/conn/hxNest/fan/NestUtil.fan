//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

using haystack

internal mixin NestUtil
{
  static const Unit celsius := Unit.fromStr("celsius")
  static const Unit relHum  := Unit.fromStr("%RH")

  static Obj? nestToHay(Obj? val, Unit? unit := null)
  {
    if (val == null)  return null
    if (val is Float) return Number.make(val, unit)
    if (val is Int)   return Number.makeInt(val, unit)
    if (val is Str)   return val

    // I give up
    return val.toStr
  }

  static Obj? getTraitVal(NestResource res, NestTraitRef ref)
  {
    nestToHay(res.traitVal(ref.trait, ref.field), toUnit(res, ref))
  }

  static Unit? toUnit(NestResource res, NestTraitRef ref)
  {
    if (ref.field.endsWith("Celsius")) return celsius
    return null
  }

}