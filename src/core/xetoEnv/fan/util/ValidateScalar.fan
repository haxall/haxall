//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::Number

**
** Validation for scalar values against meta dict
**
@Js
const class ValidateScalar
{

  static Void validate(Obj x, Dict meta, |Str| onErr)
  {
    if (meta.isEmpty) return
    if (x is Number) validateNumber(x, meta, onErr)
  }

  static Void validateNumber(Number x, Dict meta, |Str| onErr)
  {
    unit := x.unit

    min := meta["minVal"] as Number
    minUnitErr := false
    if (min != null)
    {
      if (min.unit != null && min.unit != unit)
      {
        onErr("Number $x has invalid unit, minVal requires '$min.unit'")
        minUnitErr = true
      }
      else if (x < min)
        onErr("Number $x < minVal $min")
    }

    max := meta["maxVal"] as Number
    if (max != null)
    {
      if (max.unit != null && max.unit != unit)
      {
        if (!minUnitErr)
          onErr("Number $x has invalid unit, maxVal requires '$max.unit'")
      }
      else if (x > max)
        onErr("Number $x > maxVal $max")
    }

    quantity := meta["quantity"] as Str
    if (quantity != null)
    {
      if (unit == null)
      {
        onErr("Number must be '$quantity' unit; no unit specified")
      }
      else
      {
        q := unitToQuantity[unit]
        if (q == null)
          onErr("Number must be '$quantity' unit; '$unit' has no quantity")
        else if (q != quantity)
          onErr("Number must be '$quantity' unit; '$unit' has quantity of '$q'")

      }
    }
  }

  static const Unit:Str unitToQuantity
  static
  {
    acc := Unit:Str[:]
    Unit.quantities.each |q|
    {
      Unit.quantity(q).each |u| { acc[u] = q }
    }
    unitToQuantity = acc
  }
}