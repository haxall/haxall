//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Aug 2022  Brian Frank  Creation
//

using util

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
  Void info(Str msg) { log(LogLevel.info, msg, FileLoc.unknown, null) }

  ** Report warning level
  Void warn(Str msg, FileLoc loc, Err? cause := null) { log(LogLevel.warn, msg, loc, cause) }

  ** Report err level
  Void err(Str msg, FileLoc loc, Err? cause := null) { log(LogLevel.err, msg, loc, cause) }

  ** Report log message
  abstract Void log(LogLevel level, Str msg, FileLoc loc, Err? cause)
}

**************************************************************************
** XetoOutStreamLog
**************************************************************************

@Js
internal class XetoOutStreamLog : XetoLog
{
  new make(OutStream out) { this.out = out }

  override Void log(LogLevel level, Str msg,  FileLoc loc, Err? cause)
  {
    if (loc !== FileLoc.unknown) out.print(loc).print(": ")
    if (level == LogLevel.warn) out.print("WARN ")
    out.printLine(msg)
    if (cause != null) cause.trace(out)
  }

  private OutStream out
}

**************************************************************************
** XetoWrapperLog
**************************************************************************

@Js
internal class XetoWrapperLog : XetoLog
{
  new make(Log wrap) { this.wrap = wrap }

  const Log wrap

  override Void log(LogLevel level, Str msg,  FileLoc loc, Err? cause)
  {
    wrap.log(LogRec(DateTime.now, level, wrap.name, msg, cause))
  }
}


