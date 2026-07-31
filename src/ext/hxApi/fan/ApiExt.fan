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
    this.web = ApiWeb(this)
    this.pipelineType = Type.find(sys.config.get("apiPipeline") ?: ApiPipeline#.qname)
    if (!pipelineType.fits(ApiPipeline#))
      throw ArgErr("apiPipeline is not an ApiPipeline: $pipelineType")
    syncErrTrace
  }

  ** Settings record
  override ApiSettings settings() { super.settings }

  ** Push the disableErrTrace setting down to ApiErr which services
  ** every API error response
  override Void onSettings() { syncErrTrace }

  private Void syncErrTrace()
  {
    ApiErr.disableErrTrace.val = settings.disableErrTrace
  }

  ** Web servicing
  override const ApiWeb web

  ** Pipeline class used to service each API request.  A vendor plugs in
  ** its own dispatch by naming a subclass in the "apiPipeline" sysConfig.
  @NoDoc const Type pipelineType
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

