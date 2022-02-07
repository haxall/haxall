//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

**
** Ecobee error info
**
const class EcobeeErr : Err
{
  new make(EcobeeStatus status, Err? cause := null) : super(status.message, cause)
  {
    this.status = status
  }

  ** Status
  const EcobeeStatus status

  Int code() { status.code }

  Str message() { status.message }

  override Str toStr() { status.toStr }

}