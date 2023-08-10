//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto
using haystack::UnknownLibErr

**
** RemoteRegistry implementation
**
@Js
internal const class RemoteRegistry : MRegistry
{
  new make(XetoClient client, RemoteRegistryEntry[] list)
  {
    this.client = client
    this.list = list
    this.map  = Str:RemoteRegistryEntry[:].addList(list) { it.name }
  }

  override RemoteRegistryEntry? get(Str qname, Bool checked := true)
  {
    x := map[qname]
    if (x != null) return x
    if (checked) throw UnknownLibErr("Not installed: $qname")
    return null
  }

  override Lib? loadSync(Str qname, Bool checked := true)
  {
    // check for install
    entry := get(qname, checked)
    if (entry == null) return null

    // check for cached loaded lib
    if (entry.isLoaded) return entry.get

    // cannot use this method to load
    throw Err("Remote lib $qname.toCode not loaded, must use libAsync")
  }

  override Void loadAsync(Str qname,|Lib?| f)
  {
    // check for install
    entry := get(qname, false)
    if (entry == null) { f(null); return }

    // check for cached loaded lib
    if (entry.isLoaded) { f(entry.get); return }

    // load from transport
    client.loadLib(qname) |lib|
    {
      if (lib != null)
      {
        entry.set(lib)
        lib = entry.get
      }

      f(lib)
    }
  }

  override Int build(LibRegistryEntry[] libs)
  {
    throw UnsupportedErr()
  }

  const XetoClient client
  override const RemoteRegistryEntry[] list
  const Str:RemoteRegistryEntry map
}

**************************************************************************
** RemoteRegistryEntry
**************************************************************************

@Js
internal const class RemoteRegistryEntry : MRegistryEntry
{
  new make(Str name)
  {
    this.name = name
  }

  override const Str name

  override Version version() { Version.defVal }

  override Str doc() { "" }

  override Str toStr() { name }

  override File zip() { throw UnsupportedErr() }

  override Bool isSrc() { false }

  override File? srcDir(Bool checked := true) { throw UnsupportedErr() }

}

