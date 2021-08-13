//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Sep 2019  Brian Frank  Creation
//

using haystack
using hx
using axon

**************************************************************************
** IOStreamLinesStream
**************************************************************************

internal class IOStreamLinesStream : SourceStream
{
  new make(Obj? handle) { this.handle = handle }

  override Str funcName() { "ioStreamLines" }

  override Obj?[] funcArgs() { [handle] }

  override Void onStart(Signal sig)
  {
    IOHandle.fromObj(rt, handle).withIn |in|
    {
      while (true)
      {
        line := in.readLine
        if (line == null) break
        if (isComplete) break
        submit(line)
      }
      return null
    }
  }

  HxRuntime rt() { ((HxContext)cx).rt }

  private Obj? handle
}

**************************************************************************
** IOStreamCsvStream
**************************************************************************

internal class IOStreamCsvStream : SourceStream
{
  new make(Obj? handle, Dict? opts) { this.handle = handle; this.opts = opts }

  override Str funcName() { "ioStreamCsv" }

  override Obj?[] funcArgs() { [handle, opts] }

  override Void onStart(Signal sig)
  {
    IOCsvReader(cx, handle, opts).stream(this)
  }

  private Obj? handle
  private Obj? opts
}