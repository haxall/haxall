//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

class DevicesReq : ApiReq
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  internal new make(Nest nest) : super(nest.projectId, nest.client)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Devices
//////////////////////////////////////////////////////////////////////////

  NestDevice[] list()
  {
    json := invoke("GET", projectUri.plus(`devices`))
    return (json["devices"] as List).map |d->NestDevice| { NestDevice.fromJson(d) }
  }

  NestDevice get(Str deviceId)
  {
    NestDevice.fromJson(invoke("GET", projectUri.plus(`devices/${deviceId}`)))
  }
}