//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent
using util
using xeto
using xetoEnv

**
** LocalNamespace compiles its libs from a repo
**
@Js
const class LocalNamespace : MNamespace
{
  new make(NameTable names, LibVersion[] versions, LibRepo repo)
    : super(names, versions)
  {
    this.repo = repo
  }

  const LibRepo repo
}

