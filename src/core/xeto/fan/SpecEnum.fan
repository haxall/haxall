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

  ** Get the extended meta for the given enum item key.  If key is null
  ** then get the extended meta for the enum spec itself.  This method is
  ** only available if the requested by the `LibNamespace.xmetaEnum`
  ** otherwise an exception is raised.
  abstract Dict? xmeta(Str? key := null, Bool checked := true)
}

