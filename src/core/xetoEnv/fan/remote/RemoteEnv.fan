//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto

**
** Remote environment that loads libs over a network transport layer
**
@Js
const class RemoteEnv : MEnv
{
  internal new make(NameTable names, MRegistry registry, |This| f) : super(names, registry, f)
  {
  }

  override Bool isRemote() { true }

  override Lib compileLib(Str src, Dict? opts := null)
  {
    throw UnsupportedErr()
  }

  override Obj? compileData(Str src, Dict? opts := null)
  {
    throw UnsupportedErr()
  }

  override Dict parsePragma(File file, Dict? opts := null)
  {
    throw UnsupportedErr()
  }

  override Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("=== RemoteXetoEnv ===")
    registry.list.each |entry|
    {
      out.print("  ")
         .print(entry.name.padr(32))
         .print(" [")
         .print(entry.isLoaded ? "loaded" : "not loaded")
         .printLine("]")
    }
  }
}


