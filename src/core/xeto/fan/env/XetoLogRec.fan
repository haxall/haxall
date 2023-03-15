//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Mar 2023  Brian Frank  Creation
//

using util
using data

**
** XetoLogRec implementation DataLogRec
**
@Js
const class XetoLogRec : DataLogRec
{
  new make(LogLevel level, Str msg, FileLoc loc, DataDict? rec, Err? err)
  {
    this.level = level
    this.msg   = msg
    this.loc   = loc
    this.rec   = rec
    this.err   = err
  }

  const override LogLevel level
  const override Str msg
  const override FileLoc loc
  const override DataDict? rec
  const override Err? err

  override Str toStr()
  {
    s := StrBuf()
    s.add(level.name.upper).add(": ").add(msg)
    if (!loc.isUnknown) s.add(" [").add(loc).add("]")
    return s.toStr
  }
}