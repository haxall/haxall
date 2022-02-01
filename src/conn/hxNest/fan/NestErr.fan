//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Jan 2022  Matthew Giannini  Creation
//

**
** Nest error info
const class NestErr : Err
{
  new make(Str:Obj? error, Err? cause := null) : super(error["message"], cause)
  {
    this.error = error
  }

  ** Raw error information
  const Str:Obj? error

  Int code() { error["code"] }

  Str message() { error["message"] ?: "Unknown Err" }

  override Str toStr()
  {
    buf := StrBuf().add("[$code] $message")
    return buf.toStr
  }
}