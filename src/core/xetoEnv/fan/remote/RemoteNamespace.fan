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

  internal new make(XetoBinaryIO io, NameTable names, LibVersion[] versions, RemoteLibLoader? libLoader, |This->XetoLib| loadSys)
    : super(names, versions, loadSys)
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

  override Void doLoadListAsync(LibVersion[] v, |Err?, Obj[]?| f)
  {
    acc := Obj?[,]
    doLoadListAsyncRecursive(v, 0, acc, f)
  }

  private Void doLoadListAsyncRecursive(LibVersion[] vers, Int index, Obj?[] acc, |Err?, Obj[]?| f)
  {
    if (libLoader == null) throw UnsupportedErr("No RemoteLibLoader installed")

    // load from pluggable loader
    libLoader.loadLib(vers[index].name) |err, libOrErr|
    {
      // handle error
      if (err != null)
      {
        f(err, null)
        return
      }

      // add to our results accumulator
      acc.add(libOrErr)

      // recursively load the next library in our flattened
      // depends list or if last one then invoke the callback
      index++
      if (index < vers.size)
        doLoadListAsyncRecursive(vers, index, acc, f)
      else
        f(null, acc)
    }
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

