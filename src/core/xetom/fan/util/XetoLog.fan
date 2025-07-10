//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Aug 2022  Brian Frank  Creation
//

using util
using xeto

**
** Logger is used to report compiler info, warnings, and errors
**
@Js
abstract class XetoLog
{
  **
  ** Log errors to the given output stream using the standard format:
  **
  **   filepath(line): message
  **
  ** This logger is best used when running protoc as a stand alone
  ** command line program.
  **
  static new makeOutStream(OutStream out := Env.cur.out) { XetoOutStreamLog(out) }

  **
  ** Wrap the `sys::Log` object.  This logger is best used when
  ** embedding the ProtoCompiler inside larger programs.
  **
  static new makeLog(Log log) { XetoWrapperLog(log) }

  ** Report info level
  Void info(Str msg) { log(LogLevel.info, null, msg, FileLoc.unknown, null) }

  ** Report warning level
  Void warn(Str msg, FileLoc loc, Err? err := null) { log(LogLevel.warn, null, msg, loc, err) }

  ** Report err level
  Void err(Str msg, FileLoc loc, Err? err := null) { log(LogLevel.err, null, msg, loc, err) }

  ** Report log message
  abstract Void log(LogLevel level, Ref? id, Str msg, FileLoc loc, Err? cause)
}

**************************************************************************
** XetoOutStreamLog
**************************************************************************

@Js
class XetoOutStreamLog : XetoLog
{
  new make(OutStream out) { this.out = out }

  override Void log(LogLevel level, Ref? id, Str msg,  FileLoc loc, Err? err)
  {
    if (loc !== FileLoc.unknown) out.print(loc).print(": ")
    if (level == LogLevel.warn) out.print("WARN ")
    out.printLine(msg)
    if (err != null) err.trace(out)
  }

  private OutStream out
}

**************************************************************************
** XetoWrapperLog
**************************************************************************

@Js
class XetoWrapperLog : XetoLog
{
  new make(Log wrap) { this.wrap = wrap }

  const Log wrap

  override Void log(LogLevel level, Ref? id, Str msg,  FileLoc loc, Err? err)
  {
    wrap.log(LogRec(DateTime.now, level, wrap.name, msg, err))
  }
}

**************************************************************************
** XetoCallbackLog
**************************************************************************

@Js
class XetoCallbackLog : XetoLog
{
  new make(|XetoLogRec| cb) { this.cb = cb }

  override Void log(LogLevel level, Ref? id, Str msg,  FileLoc loc, Err? err)
  {
    cb(XetoLogRec(level, id, msg, loc, err))
  }

  private |XetoLogRec| cb
}

