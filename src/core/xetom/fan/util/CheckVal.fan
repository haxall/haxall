//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Dec 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Validation for values against a spec type and meta
**
@Js
const class CheckVal
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Dict opts)
  {
    this.opts = opts
    this.fidelity = XetoUtil.optFidelity(opts)
  }

//////////////////////////////////////////////////////////////////////////
// Val
//////////////////////////////////////////////////////////////////////////

  Void check(Spec spec, Obj x, |Str| onErr)
  {
    checkFixed(spec, x, onErr)
    if (spec.isScalar) return checkScalar(spec, x, onErr)
    if (spec.isList) return checkList(spec, x, onErr)
  }

//////////////////////////////////////////////////////////////////////////
// Final
//////////////////////////////////////////////////////////////////////////

  private Void checkFixed(Spec spec, Obj x, |Str| onErr)
  {
    if (spec.meta.missing("fixed")) return

    // get the expected fixed value
    expect := spec.meta.get("val")

    // check if actual matches expected fixed value
    if (Etc.eq(expect, x)) return

    // narrow expected value if using less than full fidelity
    narrow := fidelity.coerce(expect)
    if (narrow !== expect)
    {
      if (Etc.eq(narrow, x)) return
    }

    // no joy
    onErr("Must have fixed value '$expect'")
  }

//////////////////////////////////////////////////////////////////////////
// List
//////////////////////////////////////////////////////////////////////////

  private static Void checkList(Spec spec, Obj obj, |Str| onErr)
  {
    x := obj as List

    // should not happen, but just in case
    if (x == null)
    {
      onErr("Not list type: $obj.typeof")
      return
    }

    // check non-empty
    nonEmpty := spec.meta.get("nonEmpty")
    if (nonEmpty != null && x.isEmpty)
    {
      onErr("List must be non-empty")
    }

    // minSize
    minSize := toInt(spec.meta.get("minSize"))
    if (minSize != null && x.size < minSize)
    {
      onErr("List size $x.size < minSize $minSize")
    }

    // maxSize
    maxSize := toInt(spec.meta.get("maxSize"))
    if (maxSize != null && x.size > maxSize)
    {
      onErr("List size $x.size > maxSize $maxSize")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Scalar
//////////////////////////////////////////////////////////////////////////

  private Void checkScalar(Spec spec, Obj x, |Str| onErr)
  {
    if (x is Number) return checkNumber(spec, x, onErr)
    if (spec.type.isEnum) return checkEnum(spec, x, onErr)
    if (x is Str || x is Scalar) return checkStr(spec, x.toStr, onErr)
  }

//////////////////////////////////////////////////////////////////////////
// Number
//////////////////////////////////////////////////////////////////////////

  private static Void checkNumber(Spec spec, Number x, |Str| onErr)
  {
    meta := spec.meta
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

    quantity := meta["quantity"]
    if (quantity != null)
    {
      if (unit == null)
      {
        onErr("Number must be '$quantity' unit; no unit specified")
      }
      else
      {
        q := UnitQuantity.unitToQuantity[unit]
        if (q == null)
          onErr("Number must be '$quantity' unit; '$unit' has no quantity")
        else if (q != quantity)
          onErr("Number must be '$quantity' unit; '$unit' has quantity of '$q'")

      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  private Void checkEnum(Spec spec, Obj x, |Str| onErr)
  {
    // value must be string key, Scalar, or mapped by factory to Enum
    key := x as Str
    if (key == null) key = (x as Scalar)?.val
    if (key == null) key = (x as Enum)?.name
    if (key == null) key = (x as Unit)?.symbol
    if (key == null) key = (x as TimeZone)?.name
    if (key == null) return onErr("Invalid enum value type, $x.typeof not Str")

    // verify key maps to enum item
    enum := spec.type
    item := enum.enum.spec(key, false)
    if (item == null) return onErr("Invalid key '$key' for enum type '$enum.qname'")

    // special handling for unit
    if (enum.qname == "sys::Unit")
    {
      q := spec.meta["quantity"]
      if (q != null)
      {
        unitQuantity := item.meta["quantity"]
        if (q != unitQuantity) onErr("Unit '$key' must be '$q' not '$unitQuantity'")
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Str
//////////////////////////////////////////////////////////////////////////

  private static Void checkStr(Spec spec, Str x, |Str| onErr)
  {
    if (!spec.isScalar) return

    // check regex pattern
    pattern := spec.meta.get("pattern") as Str
    if (pattern != null)
    {
      if (!Regex(pattern).matches(x))
      {
        errType := errTypeForMeta(spec, "pattern", pattern)
        onErr("String encoding does not match pattern for '$errType'")
      }
    }

    // check non-empty
    nonEmpty := spec.meta.get("nonEmpty")
    if (nonEmpty != null && x.trim.isEmpty)
    {
      errType := errTypeForMeta(spec, "nonEmpty", nonEmpty)
      onErr("String must be non-empty")
    }

    // minSize
    minSize := toInt(spec.meta.get("minSize"))
    if (minSize != null && x.size < minSize)
    {
      onErr("String size $x.size < minSize $minSize")
    }

    // maxSize
    maxSize := toInt(spec.meta.get("maxSize"))
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
  static Str errTypeForMeta(Spec spec, Str key, Obj val)
  {
    if (spec.type.meta.get(key) == val)
      return spec.type.qname
    else
      return spec.qname
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const Dict opts
  const XetoFidelity fidelity

}

