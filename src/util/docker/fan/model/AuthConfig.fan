//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2021  Matthew Giannini  Creation
//

using util

class AuthConfig
{
  new make(Str username, Str password)
  {
    this.username = username
    this.password = password
  }

  Str username { private set }
  This withUsername(Str username) { this.username = username; return this }

  Str password { private set }
  This withPasword(Str password) { this.password = password; return this }

  Str? email { private set }
  This withEmail(Str? email) { this.email = email; return this}

  Str? serverAddress { private set }
  This withServerAddress(Str serverAddress) { this.serverAddress = serverAddress; return this}

  Str encode()
  {
    json    := JsonEncoder.encode(this)
    jsonStr := JsonOutStream.writeJsonToStr(json)
    return jsonStr.toBuf.toBase64Uri
  }
}