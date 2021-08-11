//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jan 2010  Brian Frank  Creation
//

**
** FtpErr indicates an error during an FTP messaging.
**
const class FtpErr : Err
{

  **
  ** Construct with error code, message, and optional cause.
  **
  new make(Int code, Str? msg, Err? cause := null)
    : super(msg, cause)
  {
    this.code = code
  }

  **
  ** The FTP status
  **
  const Int code
}