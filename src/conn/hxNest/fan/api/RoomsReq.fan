//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   01 Feb 2022  Matthew Giannini  Creation
//

class RoomsReq : ApiReq
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  internal new make(Nest nest) : super(nest.projectId, nest.client)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Structures
//////////////////////////////////////////////////////////////////////////

  NestRoom[] list(Str structureId)
  {
    acc    := NestRoom[,]
    params := Str:Str[:]
    while (true)
    {
      json := invoke("GET", projectUri.plus(`structures/${structureId}/rooms`).plusQuery(params))
      (json["rooms"] as List).each |r| { acc.add(NestRoom(r)) }

      // get next page
      nextPageToken := json["nextPageToken"] as Str
      if (nextPageToken == null) break
      params = ["pageToken": nextPageToken]
    }

    return acc
  }

  NestRoom get(Str structureId, Str roomId)
  {
    NestRoom(invoke("GET", projectUri.plus(`structures/${structureId}/rooms/${roomId}`)))
  }
}