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
using xetom
using haystack

**
** LocalNamespace compiles its libs from a repo
**
const class LocalNamespace : MNamespace
{
  new make(LocalNamespaceInit init)
    : super(init.env, init.versions, init.opts)
  {
//    this.repo  = init.repo
  }

//  const LibRepo repo

//////////////////////////////////////////////////////////////////////////
// Loading
//////////////////////////////////////////////////////////////////////////

/*
  override Void doLoadAsync(LibVersion version, |Err?, Obj?| f)
  {
    try
      f(null, doLoadSync(version))
    catch (Err e)
      f(null, e)
  }
*/
}


**************************************************************************
** LocalNamespaceInit
**************************************************************************

const class LocalNamespaceInit
{
  new make(XetoEnv env, LibRepo repo, LibVersion[] versions, Dict opts := Etc.dict0)
  {
    this.env      = env
    this.repo     = repo
    this.versions = versions
    this.opts     = opts
  }

  const MEnv env
  const LibRepo repo
  const LibVersion[] versions
  const Dict opts
}

