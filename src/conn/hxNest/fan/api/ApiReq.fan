//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

using web
using util
using oauth2

**
** Nest SDM API request
**
class ApiReq
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  internal new make(Str projectId, OAuthClient client)
  {
    this.projectId = projectId
    this.client = client
  }

  private static const Uri baseUri := `https://smartdevicemanagement.googleapis.com/v1/`

  protected const Str projectId
  protected const OAuthClient client

  ** Get the project uri endpoint
  protected Uri projectUri() { baseUri.plus(`enterprises/${projectId}/`) }

//////////////////////////////////////////////////////////////////////////
// Invoke
//////////////////////////////////////////////////////////////////////////

  Map? invoke(Str method, Uri uri, Obj? req := null, [Str:Str] headers := [:])
  {
    readJson(call(method, uri, req, headers))
  }

  @NoDoc WebClient call(Str method, Uri uri, Obj? req := null, [Str:Str] headers := [:])
  {
    c := client.call(method, uri, req, headers)

    // check for successful call
    if (c.resCode / 100 == 2) return c

    // handle error
    try
    {
      // this should throw a NestErr
      json := readJson(c)
      // but if it doesn't throw a general IOErr
      throw IOErr("[$c.resCode] $c.resPhrase\n$json")
    }
    finally c.close
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  internal static Map readJson(WebClient c)
  {
    // check for 204 No-Content response
    if (c.resCode == 204) return [:]

    // decode the json response
    str := c.resStr
    json := (Map)JsonInStream(str.in).readJson

    // check for an API error
    err := json["error"] as Map
    if (err != null) throw NestErr(err)

    return json
  }
}