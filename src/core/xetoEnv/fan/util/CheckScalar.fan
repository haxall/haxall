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
** Validation for scalar values against a spec type and meta
**
@Js
const class CheckScalar
{

  static Void check(CSpec spec, Obj x, |Str| onErr)
  {
    if (x is Number) return checkNumber(spec, x, onErr)
    if (spec.ctype.isEnum) return checkEnum(spec, x, onErr)
  }

  static Void checkNumber(CSpec spec, Number x, |Str| onErr)
  {
    meta := spec.cmeta
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

    reqUnit := meta["unit"] as Str
    if (reqUnit != null)
    {
      if (reqUnit != unit?.symbol)
        onErr("Number $x must have unit of '$reqUnit'")
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

  static Void checkEnum(CSpec spec, Obj x, |Str| onErr)
  {
    // value must be string key or mapped by factory to Enum
    key := x as Str
    if (key == null) key = (x as Enum)?.name
    if (key == null) return onErr("Invalid enum value type, $x.typeof not Str")

    // verify key maps to enum item
    enum := spec.ctype
    item := enum.cenum(key, false)
    if (item == null) return onErr("Invalid key '$key' for enum type '$enum.qname'")

    // special handling for unit
    if (enum.qname == "sys::Unit")
    {
      q := spec.cmeta["quantity"] as Str
      if (q != null)
      {
        unitQuantity := item.cmeta["quantity"]
        if (q != unitQuantity) onErr("Unit '$key' must be '$q' not '$unitQuantity'")
      }
    }

  }
}

