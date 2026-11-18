//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Dec 2023  Brian Frank  Creation
//

using util

**
** Item metadata for an Enum spec
**
@Js
const mixin SpecEnum
{
  ** Lookup enum item spec by its string key
  abstract Spec? spec(Str key, Bool checked := true)

  ** List the string keys
  abstract Str[] keys()

  ** Iterate the enum items by spec and string key
  abstract Void each(|Spec,Str| f)
}

**************************************************************************
** KeyedEnum
**************************************************************************

**
** KeyedEnum is implemented by a Fantom enum bound to a Xeto enum
** whose keys differ from its item names.  The key is the string
** value of the item in Xeto: an item declared `iconXs <key:"icon-xs">`
** has the name "iconXs" and the key "icon-xs".
**
@Js
mixin KeyedEnum
{
  ** Find the item of the given enum type by its key.  If not found
  ** and checked is false return null, otherwise throw ParseErr.
  static KeyedEnum? fromKey(Type type, Str key, Bool checked := true)
  {
    val := ((KeyedEnum[])type.field("vals").get).find |x| { x.key == key }
    if (val != null) return val
    if (checked) throw ParseErr("Unknown key for $type.qname: $key.toCode")
    return null
  }

  ** Key of this item: its string value in Xeto
  abstract Str key()
}

