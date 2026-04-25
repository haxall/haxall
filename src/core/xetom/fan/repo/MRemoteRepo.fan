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
abstract const class MRemoteRepo : MRepo, RemoteRepo
{
  static MRemoteRepo create(RemoteRepoInit init)
  {
    // check indexed props to match a URI to a specific fantom type:
    //    "xeto.repo": "uri qname"
    //    "xeto.repo": "http://test-1/ testXeto::TestRemoteRepo"
    typeName := Env.cur.index("xeto.repo").eachWhile |str|
    {
      sp := str.index(" ")
      if (sp == null) return  null
      uri := str[0..<sp]
      if (uri != init.uri.toStr) return null
      return str[sp+1..-1]
    }
    if (typeName == null) return TempRemoteRepo(init)
    return Type.find(typeName).make([init])
  }

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

}

**************************************************************************
** TempRemoteRepo
**************************************************************************

internal const class TempRemoteRepo : MRemoteRepo
{
  new make(RemoteRepoInit init) : super(init) {}

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

