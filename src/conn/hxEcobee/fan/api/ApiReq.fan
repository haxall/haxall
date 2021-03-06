//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using concurrent
using web
using util
using oauth2

**
** Ecobee API request
**
class ApiReq
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(OAuthClient client, Log? log := null)
  {
    this.client = client
    this.log = log
  }

  internal static const Uri baseUri := `https://api.ecobee.com/1/`

  protected const OAuthClient client

  protected const Log? log

  private Bool isDebug() { log?.isDebug ?: false }

  private static const AtomicInt debugCounter := AtomicInt()

//////////////////////////////////////////////////////////////////////////
// Invoke
//////////////////////////////////////////////////////////////////////////

  ** Convenience to do a GET to an ecobee endpoint. Handles setting the
  ** Content-Type and encoding the json into the request uri.
  EcobeeObj invokeGet(Uri endpoint, EcobeeObj obj, Int? page := null)
  {
    // encode body
    bodyJson := Str:Obj?[obj.jsonKey: obj]
    if (page != null) bodyJson["page"] = EcobeePage(page)
    body  := EcobeeEncoder.jsonStr(bodyJson)

    // invoke
    query := ["format":"json", "body": body]
    json  :=  invoke("GET", baseUri.plus(endpoint).plusQuery(query))

    // return a typed response
    respType := typeof.pod.type("${endpoint.path.last.capitalize}Resp", false) ?: EcobeeResp#
    return EcobeeDecoder().decode(json, respType)
  }

  Map invoke(Str method, Uri uri, Obj? req := null, [Str:Str] headers := [:])
  {
    c := call(method, uri, req, headers)
    return readJson(c)
  }

  @NoDoc WebClient call(Str method, Uri uri, Obj? req := null, [Str:Str] headers := [:])
  {
    attempt := 0
    while (true)
    {
      // debug
      count := debugCounter.getAndIncrement
      if (isDebug)
      {
        s := StrBuf().add("> [$count]\n")
          .add("$method $uri\n")
        headers.each |v, n| { s.add("$n: $v\n") }
        if (req is Str) s.add(((Str)req).trimEnd).add("\n")
        if (req is File) s.add(((File)req).readAllStr.trimEnd).add("\n")
        log.debug(s.toStr)
      }

      ++attempt
      c := client.call(method, uri, req, headers)

      // Ecobee only returns 200 on success, and 500 on error
      // For errors, we must decode the status and check it
      if (c.resCode == 200) return c

      // handle error
      try
      {
        // handle unexpected http response code
        if (c.resCode != 500) throw IOErr("Unexpected response [$c.resCode] ${c.resPhrase}")

        // need to get error from response Status object
        json := readJson(c, count)
        EcobeeResp resp := EcobeeDecoder().decode(json, EcobeeResp#)

        // if the token is expired and we haven't retried yet,
        // then refresh the token and try again.
        //
        // NOTE: this is dumb. the ecobee api should be using 401 http response
        // code to indicate this so oauth client can auto refresh. but we have
        // to handle it ourselves because the error code is pushed into the status
        if (resp.status.isTokenExpired && attempt < 2)
        {
          client.refreshToken
          continue
        }

        // throw an EcobeeErr with the status
        throw EcobeeErr(resp.status)
      }
      finally c.close
    }
    throw IOErr("Compiler requires this")
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Map readJson(WebClient c, Int count := debugCounter.val - 1)
  {
    jstr := c.resStr

    // debug
    if (isDebug)
    {
      s := StrBuf().add("< [$count]\n")
        .add("$c.resCode $c.resPhrase\n")
      c.resHeaders.each |v, n| { s.add("$n: $v\n") }
      s.add("${jstr.trimEnd}\n")
      log.debug(s.toStr)
    }

    return JsonInStream(jstr.in).readJson
  }
}