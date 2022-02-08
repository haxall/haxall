//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Feb 2022  Matthew Giannini  Creation
//

using web
using util
using concurrent

**
** Utility to help with obtaining an Ecobee refresh token.
**
@NoDoc class EcobeeAuthorization : AbstractMain
{

  @Opt{ help = "Authorization scope. Must be one of: smartRead, smartWrite, ems" }
  Str scope := "smartRead"

  override Int run()
  {
    // Get the API key
    apiKey := Env.cur.prompt("Ecobee API Key: ")

    params := Str:Str[
      "response_type": "ecobeePin",
      "client_id":     apiKey,
      "scope":         scope,
    ]
    s := WebClient(`https://api.ecobee.com/authorize`.plusQuery(params)).getStr
    json := (Map)JsonInStream(s.in).readJson
    pin  := json["ecobeePin"]
    poll := Duration.fromStr(json["interval"].toStr + "sec")

    Env.cur.out.printLine(
      """
         Go to your portal and 'My Apps' and select 'Add Application'.
         Validate your application with this PIN:

             ${pin}
         """)

    params = Str:Str[
      "grant_type": "ecobeePin",
      "client_id":   apiKey,
      "code":        json["code"],
      "ecobee_type": "jwt",
    ]

    start := DateTime.now
    while (true)
    {
      Actor.sleep(poll)
      s = WebClient(`https://api.ecobee.com/token`).postForm(params).resStr
      json = (Map)JsonInStream(s.in).readJson
      if (json["access_token"] != null) break
      if (DateTime.now - start > 2min) throw Err("Took too long to validate pin")
    }

    Env.cur.out.printLine("Ecobee API Key: $apiKey")
    Env.cur.out.printLine("Ecobee Refresh Token: " + json["refresh_token"])
    return 0
  }
}