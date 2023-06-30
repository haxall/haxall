//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Mar 2023  Brian Frank  Creation
//

using util

**
** DataLogRec models a message from a DataEnv operation.
** It is used to report compiler errors and explanations.
**
@Js
const mixin DataLogRec
{
  ** Severity level of the issue
  abstract LogLevel level()

  ** String message of the issue
  abstract Str msg()

  ** File location of issue or unknown
  abstract FileLoc loc()

  ** Exception that caused the issue if applicable
  abstract Err? err()
}