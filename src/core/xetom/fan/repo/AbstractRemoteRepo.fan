//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Apr 2026  Brian Frank  Creation
//

using xeto

**
** AbstractRemoteRepo is based class for all RemoteRepo implementations
**
@Js
const class AbstractRemoteRepo : RemoteRepo
{
  new make(RemoteRepoInit init)
  {
    this.name = init.name
    this.uri  = init.uri
    this.meta = init.meta
  }

  override const Str name

  override const Uri uri

  override const Dict meta

  override final Bool isLocal() { false }

  override final Bool isRemote() { true }
}

**************************************************************************
** RemoteRepoInit
**************************************************************************

@Js
const class RemoteRepoInit
{
  new make(Str n, Uri u, Dict m) { name = n; uri = u; meta = m }
  const Str name
  const Uri uri
  const Dict meta
}

