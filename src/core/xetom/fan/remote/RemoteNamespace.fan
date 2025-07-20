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
** Remote namespace that loads libs over a network transport layer.
** Create a new remote env via `XetoBinaryReader.readBoot`.
**
@Js
const class RemoteNamespace : MNamespace
{
  ** Boot a RemoteEnv from the given boot message input stream
  static RemoteNamespace boot(XetoEnv env, InStream in, MNamespace? base, RemoteLibLoader? libLoader)
  {
    if (base == null)
      return XetoBinaryReader(in).readBootBase(env, libLoader)
    else
      return XetoBinaryReader(in).readBootOverlay(env, base, libLoader)
  }

  internal new make(MEnv env, MNamespace? base, LibVersion[] versions, RemoteLibLoader? libLoader, |This->XetoLib| loadSys)
    : super(env, base, versions, loadSys)
  {
    this.libLoader = libLoader
  }

  const RemoteLibLoader? libLoader

  override Bool isRemote() { true }

  override Lib compileLib(Str src, Dict? opts := null)
  {
    throw UnsupportedErr()
  }

  override Obj? compileData(Str src, Dict? opts := null)
  {
    throw UnsupportedErr()
  }

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

