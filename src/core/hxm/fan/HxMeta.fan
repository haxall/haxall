//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Nov 2025  Brian Frank  Creation
//

using xeto
using haystack
using hx
using hxUtil
using folio

**
** RuntimeMeta implementation
**
const class HxMeta : WrapDict, RuntimeMeta
{
  new make(HxRuntime rt, Dict rec) : super(norm(rt, rec))
  {
    this.rec = rec
    this.steadyState = duration("steadyState", 10sec).clamp(0sec, 1hr)
    this.evalTimeout = duration("evalTimeout", Context.timeoutDef).clamp(100ms, 10min)
  }

  private Dict norm(HxRuntime rt, Dict rec)
  {
    Etc.dictSet(rec, "name", rt.name)
  }

  private Duration duration(Str name, Duration def)
  {
    (rec[name] as Number)?.toDuration ?: def
  }

  override const Dict rec

  override const Duration steadyState

  override const Duration evalTimeout

}

