//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jul 2025  Brian Frank  Garden City Beach
//

using concurrent
using xeto

**
** LibCache pins a graph of Libs in memory for reuse. It may be backed
** by a LibRepo to lazily compile libs into memory.  Or when used in the
** browser libs must be manually loaded.
**
@Js
const class LibCache
{
  ** Get the lib in the cache or try to comile it
  XetoLib getOrCompile(LibNamespace ns, LibVersion v)
  {
    map.get(v.toStr) ?: map.getOrAdd(v.toStr, compile(ns, v))
  }

  ** Hook to to compile
  protected virtual XetoLib compile(LibNamespace ns, LibVersion v)
  {
    throw UnsupportedErr("Lib cannot be compiled, must be preloaded: $v")
  }

  ** Clear the cache
  Void clear()
  {
    map.clear
  }

  private const ConcurrentMap map := ConcurrentMap()
}

