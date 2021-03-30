//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2019  Brian Frank  Creation
//

**
** Define annotates facet types which coin a def from a Fantom type or slot.
**
@NoDoc @Js
const mixin Define
{

  ** Decode each key/value pair defined
  @NoDoc abstract Void decode(|Str name, Obj val| f)

}