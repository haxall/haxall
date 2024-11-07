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
    if (x is Str) return checkStr(spec, x, onErr)
  }

//////////////////////////////////////////////////////////////////////////
// Number
//////////////////////////////////////////////////////////////////////////

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

    reqUnit := meta["unit"] as Unit
    if (reqUnit != null)
    {
      if (reqUnit != unit)
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

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  static Void checkEnum(CSpec spec, Obj x, |Str| onErr)
  {
    // value must be string key or mapped by factory to Enum
    key := x as Str
    if (key == null) key = (x as Enum)?.name
    if (key == null) key = (x as Unit)?.symbol
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

//////////////////////////////////////////////////////////////////////////
// Str
//////////////////////////////////////////////////////////////////////////

  static Void checkStr(CSpec spec, Str x, |Str| onErr)
  {
    if (!spec.isScalar) return

    // check regex pattern
    pattern := spec.cmeta.get("pattern") as Str
    if (pattern != null)
    {
      if (!Regex(pattern).matches(x))
      {
        errType := errTypeForMeta(spec, "pattern", pattern)
        onErr("String encoding does not match pattern for '$errType'")
      }
    }

    // check non-empty
    nonEmpty := spec.cmeta.get("nonEmpty")
    if (nonEmpty != null && x.trim.isEmpty)
    {
      errType := errTypeForMeta(spec, "nonEmpty", nonEmpty)
      onErr("String must be non-empty for '$errType'")
    }

    // minSize
    minSize := toInt(spec.cmeta.get("minSize"))
    if (minSize != null && x.size < minSize)
    {
      onErr("String size $x.size < minSize $minSize")
    }

    // maxSize
    maxSize := toInt(spec.cmeta.get("maxSize"))
    if (maxSize != null && x.size > maxSize)
    {
      onErr("String size $x.size > maxSize $maxSize")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Coerce value to integer
  static Int? toInt(Obj? v)
  {
    if (v is Int) return v
    if (v is Number) return ((Number)v).toInt
    return null
  }

  ** Given a meta key and value, determine if we should report error
  ** using the slot or the type based on who defines the meta key
  static Str errTypeForMeta(CSpec spec, Str key, Obj val)
  {
    if (spec.ctype.cmeta.get(key) == val)
      return spec.ctype.qname
    else
      return spec.qname
  }
}

