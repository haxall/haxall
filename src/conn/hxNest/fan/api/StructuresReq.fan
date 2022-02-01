//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

class StructuresReq : ApiReq
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

  NestStructure[] list()
  {
    acc    := NestStructure[,]
    params := Str:Str[:]
    while (true)
    {
      json := invoke("GET", projectUri.plus(`structures`).plusQuery(params))
      (json["structures"] as List).each |s| { acc.add(NestStructure(s)) }

      // get next page
      nextPageToken := json["nextPageToken"] as Str
      if (nextPageToken == null) break
      params = ["pageToken": nextPageToken]
    }

    return acc
  }

  NestStructure get(Str structureId)
  {
    NestStructure(invoke("GET", projectUri.plus(`structures/${structureId}`)))
  }
}
