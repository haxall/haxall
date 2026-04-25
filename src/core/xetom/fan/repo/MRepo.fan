//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Apr 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** Base class for all LibRepos
**
@Js
abstract const class MRepo : LibRepo
{
  new make(MEnv env)
  {
    this.env = env
  }

  const MEnv env

  override LibRepoSearchRes search(LibRepoSearchReq req)
  {
    throw Err("not done!")
  }
}

