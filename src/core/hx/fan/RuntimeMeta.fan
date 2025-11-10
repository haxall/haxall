//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Nov 2025  Brian Frank  Creation
//

using xeto
using haystack

**
** Runtime meta data stored in "rt:meta" record.  This dict
** always include a synthetic 'name' tag with `Runtime.name`.
**
const mixin RuntimeMeta : Dict
{
  ** Record dict as stored in folio database with 'rt:meta' tag
  @NoDoc abstract Dict rec()

  ** Configured steady state delay or default
  @NoDoc abstract Duration steadyState()

  ** Configured evaluate timeout or default
  @NoDoc abstract Duration evalTimeout()
}

