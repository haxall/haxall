//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Oct 2018  Brian Frank  Creation
//

using xeto
using haystack::Lib

**
** Def models a definition dictionary
**
@Js
const mixin Def : Dict
{
  ** Symbolic identifier for this definition
  abstract Symbol symbol()

  ** Return simple name of definition
  abstract Str name()

  ** Library which scopes this definition
  @NoDoc abstract Lib lib()
}

