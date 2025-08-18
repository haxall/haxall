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
using haystack

**
** Remote namespace that loads libs over a network transport layer.
** Create a new remote namespace via XetoEnv.createNamespace
**
@Js
const class RemoteNamespace : MNamespace
{
  internal new makeCache(MEnv env, LibVersion[] versions)
    : super.make(env, versions)
  {
  }

  const RemoteLibLoader? libLoader

  override Void doLoadAsync(LibVersion v, |Err?, Obj?| f)
  {
    if (libLoader == null) throw UnsupportedErr("No RemoteLibLoader installed")
    libLoader.loadLib(v.name, f)
  }
}

**************************************************************************
** RemoteLibLoader
**************************************************************************

** Handler to async load a remote lib
@Js
const mixin RemoteLibLoader
{
  abstract Void loadLib(Str name, |Err?, Obj?| f)
}

