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
  static RemoteNamespace boot(InStream in, MNamespace? base, RemoteLibLoader? libLoader)
  {
    if (base == null)
      return XetoBinaryIO.makeClientStart.reader(in).readBootBase(libLoader)
    else
      return XetoBinaryIO(base).reader(in).readBootOverlay(base, libLoader)
  }

  internal new make(XetoBinaryIO io, MNamespace? base, NameTable names, LibVersion[] versions, RemoteLibLoader? libLoader, |This->XetoLib| loadSys)
    : super(base, names, versions, loadSys)
  {
    this.io = io
    this.libLoader = libLoader
  }

  const XetoBinaryIO io

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

  override XetoLib doLoadSync(LibVersion v)
  {
    throw UnsupportedErr("Must use libAsync [$v]")
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

