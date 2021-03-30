//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jan 2016  Brian Frank  Creation
//

**
** XStr is an extended string which is a type name and value
** encoded as a string.  It is used as a generic value when
** an XStr is decoded without any predefind Fantom type.
**
@Js
const final class XStr
{
  ** Decode into its appropiate Fantom type or fallback to generic XStr
  static Obj decode(Str type, Str val)
  {
    if (type == "Bin")  return Bin(val)
    if (type == "Span") return Span(val)
    return make(type, val)
  }

  ** Construct XStr type/value pair for given type
  internal static new encode(Obj val)
  {
     makeImpl(val.typeof.name, val.toStr)
  }

  ** Construct for type name and string value
  new make(Str type, Str val)
  {
    if (!isValidType(type)) throw ArgErr("Invalid type name: $type")
    this.type = type
    this.val  = val
  }

  ** Raw constructor
  internal new makeImpl(Str type, Str val)
  {
    this.type = type
    this.val  = val
  }

  private static Bool isValidType(Str t)
  {
    if (t.isEmpty || !t[0].isUpper) return false
    return t.all |c| { c.isAlphaNum || c == '_' }
  }

  ** Type name
  const Str type

  ** String value
  const Str val

  ** Hash is composed of type and val
  override Int hash() { type.hash.xor(val.hash) }

  ** Equality is base on type and val
  override Bool equals(Obj? obj)
  {
    that := obj as XStr
    if (that == null) return false
    return this.type == that.type && this.val == that.val
  }

  override Str toStr() { "$type($val.toCode)" }

  @NoDoc static const XStr defVal := XStr.makeImpl("Nil", "")
}