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
  static RemoteNamespace boot(InStream in, RemoteLibLoader? libLoader)
  {
    XetoBinaryIO.makeClient.reader(in).readBoot(libLoader)
  }

  internal new make(XetoBinaryIO io, NameTable names, LibVersion[] versions, |This->XetoLib| loadSys)
    : super(names, versions, loadSys)
  {
    this.io = io
  }

  const XetoBinaryIO io

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

  override Void doLoadListAsync(LibVersion[] v, |Err?, Obj[]?| f)
  {
echo("~~~~ doLoadListAsync: $v")
throw Err("TODO")
  }

}

**************************************************************************
** RemoteLibLoader
**************************************************************************

** Handler to async load a remote lib
@Js
const mixin RemoteLibLoader
{
  abstract Void loadLib(Str name, |Err?, Lib?| f)
}

