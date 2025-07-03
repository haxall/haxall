//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Jan 2019  Brian Frank  Creation
//

**
** DefLib models a def library
**
@NoDoc @Js
const mixin DefLib : Def
{
  ** Integer index key which matches Space.libs order
  @NoDoc abstract Int index()

  ** Base uri of the lib
  @NoDoc abstract Uri baseUri()

  ** Version of this lib
  @NoDoc abstract Version version()

  ** Dependencies
  @NoDoc abstract Symbol[] depends()
}

