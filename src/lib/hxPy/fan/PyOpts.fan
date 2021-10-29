//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2021  Matthew Giannini  Creation
//

using concurrent
using haystack

**
** Python interpreter options
**
/*
internal const class PyOpts
{
  new make(Dict? opts)
  {
    if (opts == null) opts = Etc.emptyDict

    // python home
    homeUri := opts["pythonhome"] as Uri
    this.pythonhome = homeUri == null
      ? Env.cur.workDir.plus(`.venv/`)
      : homeUri.toFile

    this.logLevel = opts.get("logLevel", "WARN").toStr

    this.timeoutRef.val = (opts.get("timeout") as Number)?.toDuration ?: 1min

    this.port = (opts["port"] as Number)?.toInt
    this.key = opts.get("key", Uuid()).toStr
  }

  ** PYTHONHOME directory (must contain python executable)
  const File pythonhome

  ** Python process log level: (WARN, INFO, DEBUG)
  const Str logLevel

  ** Eval timeout
  Duration timeout() { timeoutRef.val }
  internal const AtomicRef timeoutRef := AtomicRef(1min)

  ** The local port to bind to when launching the IPC server
  @NoDoc const Int? port := null

  ** API Key
  @NoDoc const Str key
}
*/