//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Apr 2026  Brian Frank  Creation
//

using xeto

**
** MRemoteRepo is based class for all RemoteRepo implementations
**
@Js
const class MRemoteRepo : MRepo, RemoteRepo
{
  new make(RemoteRepoInit init) : super(init.env)
  {
    this.name    = init.name
    this.uri     = init.uri
    this.meta    = init.meta
    this.pathDir = init.pathDir
  }

  override const Str name

  override const Uri uri

  override const Dict meta

  override const File pathDir

  override final Bool isLocal() { false }

  override final Bool isRemote() { true }

  override Dict? ping(Bool checked := true)
  {
    throw Err("not done!")
  }
}

**************************************************************************
** RemoteRepoInit
**************************************************************************

@Js
const class RemoteRepoInit
{
  new make(XetoEnv e, Str n, Uri u, Dict m, File d) { env = e; name = n; uri = u; meta = m; pathDir = d }
  const XetoEnv env
  const Str name
  const Uri uri
  const Dict meta
  const File pathDir
}

