//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

using concurrent
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

  internal new make(Str projectId, OAuthClient client, Log? log := null)
  {
    this.projectId = projectId
    this.client = client
    this.log = log
  }

  private static const Uri baseUri := `https://smartdevicemanagement.googleapis.com/v1/`
  private static const AtomicInt debugCounter := AtomicInt()

  protected const Str projectId
  protected const OAuthClient client
  protected const Log? log

  private Bool isDebug() { log?.isDebug ?: false }

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
    count := debugCounter.getAndIncrement
    if (isDebug)
    {
      s := StrBuf().add("> [$count]\n")
        .add("$method $uri\n")
      headers.each |v, n| { s.add("$n: $v\n") }
      if (req is Str) s.add(((Str)req).trimEnd).add("\n")
      else if (req is File) s.add(((File)req).readAllStr.trimEnd).add("\n")
      log.debug(s.toStr)
    }

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

  internal Map readJson(WebClient c, Int count := debugCounter.val -1)
  {
    // check for 204 No-Content response
    if (c.resCode == 204) return [:]

    // decode the json response
    str := c.resStr
    json := (Map)JsonInStream(str.in).readJson

    // debug
    if (isDebug)
    {
      s := StrBuf().add("< [$count]\n")
        .add("$c.resCode $c.resPhrase\n")
      c.resHeaders.each |v, n| { s.add("$n: $v\n") }
      s.add("${str.trimEnd}\n")
      log.debug(s.toStr)
    }

    // check for an API error
    err := json["error"] as Map
    if (err != null) throw NestErr(err)

    return json
  }
}