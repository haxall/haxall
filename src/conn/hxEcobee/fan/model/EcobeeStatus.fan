//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

**
** Status object
**
const class EcobeeStatus : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  new makeFields(Int code, Str message)
  {
    this.code = code
    this.message = message
  }

  ** The status code for this status
  const Int code

  ** The detailed message for this status
  const Str message

//////////////////////////////////////////////////////////////////////////
// Status
//////////////////////////////////////////////////////////////////////////

  ** Is this a successful status
  Bool isOk() { code == 0 }

  ** Is this an error status
  Bool isErr() { !isOk }

  ** Is this a token expiration error status
  internal Bool isTokenExpired() { code == 14 }

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  override Str toStr() { "[$code] $message" }
}
