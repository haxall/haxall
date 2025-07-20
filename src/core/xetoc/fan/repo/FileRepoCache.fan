//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Jul 2025  Brian Frank  Garden City Beach
//

using concurrent
using util
using xeto
using xetom

**
** FileRepoCache compiles libs from a FileRepo
**
const class FileRepoCache : LibCache
{
  new make(FileRepo repo)
  {
    this.repo = repo
  }

  const FileRepo repo

  override XetoLib compile(LibNamespace ns, LibVersion v)
  {
    c := XetoCompiler
    {
      it.ns      = ns
      it.libName = v.name
      it.input   = v.file
    }
    return c.compileLib
  }

}

