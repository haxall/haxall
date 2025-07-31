//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using xeto
using hx

**
** Haystack HTTP API service handling
**
const class ApiExt : ExtObj
{
  ** Constructor
  new make()
  {
    this.web = Type.find(sys.config.get("apiExtWeb") ?: ApiWeb#.qname).make([this])
  }

  ** Settings record
  override ApiSettings settings() { super.settings }

  ** Web servicing
  override const ApiWeb web
}


**************************************************************************
** ApiSettings
**************************************************************************

@NoDoc
const class ApiSettings : Settings
{
  ** Constructor
  new make(Dict d, |This| f) : super(d) {}

  ** Disable including stack trace when requests raise an exception.
  @Setting
  const Bool disableErrTrace := false
}

