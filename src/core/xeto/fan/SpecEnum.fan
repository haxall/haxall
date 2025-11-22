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

