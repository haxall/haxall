//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Mar 2023  Brian Frank  Creation
//

using util

**
** XetoLogRec models a message from a XetoEnv operation.
** It is used to report compiler errors and explanations.
**
@NoDoc @Js
const mixin XetoLogRec
{
  ** Constructor for default implementation
  static new make(LogLevel level, Ref? id, Str msg, FileLoc loc, Err? err)
  {
    MXetoLogRec(level, id, msg, loc, err)
  }

  ** Identifier of data record if applicable
  abstract Ref? id()

  ** Severity level of the issue
  abstract LogLevel level()

  ** String message of the issue
  abstract Str msg()

  ** File location of issue or unknown
  abstract FileLoc loc()

  ** Exception that caused the issue if applicable
  abstract Err? err()
}

**************************************************************************
** MXetoLogRec
**************************************************************************

@NoDoc @Js
const class MXetoLogRec : XetoLogRec
{
  new make(LogLevel level, Ref? id, Str msg, FileLoc loc,Err? err)
  {
    this.level = level
    this.id    = id
    this.msg   = msg
    this.loc   = loc
    this.err   = err
  }

  const override LogLevel level
  const override Ref? id
  const override Str msg
  const override FileLoc loc
  const override Err? err

  override Str toStr()
  {
    s := StrBuf()
    if (id != null) s.add("@").add(id).add(" ")
    s.add(level.name.upper).add(": ").add(msg)
    if (!loc.isUnknown) s.add(" [").add(loc).add("]")
    return s.toStr
  }
}

