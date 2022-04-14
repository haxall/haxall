//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Apr 2016  Brian Frank  Creation
//

** AuthErr
const class AuthErr : Err
{
  ** Constructor for unknown user
  static AuthErr makeUnknownUser(Str username)
  {
    makeRes("Unknown user '$username'", "Invalid username or password")
  }

  ** Constructor for invalid password
  static AuthErr makeInvalidPassword()
  {
    makeRes("Invalid password",  "Invalid username or password")
  }

  ** Standard constructor - the msg is used for public HTTP response
  new make(Str msg, Err? cause := null) : super(msg, cause)
  {
    this.resMsg = msg
  }

  ** Constructor with public HTTP response code and message
  new makeRes(Str debugMsg, Str resMsg, Int resCode := 403) : super.make(debugMsg, null)
  {
    this.resMsg = resMsg
    this.resCode = resCode
  }

  ** Status message for HTTP response when details should be shared
  const Str resMsg

  ** Status code to use for HTTP response
  const Int resCode := 403
}


