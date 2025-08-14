//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Apr 2022  Brian Frank  Creation
//

using xeto
using haystack
using hx

**
** Settings record
**
const class HxUserSettings : Settings
{
  ** Constructor
  new make(Dict d, |This| f) : super(d) { f(this) }

  ** Maximum number of all non-superuser sessions.  Super users can
  ** alwayscreate new sessions beyond this threshold.  After this limit
  ** is reached any attempt to login a new non-superuser session will
  ** return a HTTP 503 error.
  @Setting
  const Int maxSessions := 250

}

