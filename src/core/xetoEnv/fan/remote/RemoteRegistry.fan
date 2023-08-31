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
  new make(XetoTransport transport, RemoteRegistryEntry[] list)
  {
    this.transport = transport
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

  override Lib? loadSync(Str name, Bool checked := true)
  {
    // check for install
    entry := get(name, checked)
    if (entry == null) return null

    // check for cached loaded lib
    if (entry.isLoaded) return entry.get

    // cannot use this method to load
    throw Err("Remote lib $name.toCode not loaded, must use libAsync")
  }

  override Void loadAsync(Str name,|Err?, Lib?| f)
  {
    // check for install
    entry := get(name, false)
    if (entry == null) { f(UnknownLibErr(name), null); return }

    // check for cached loaded lib
    if (entry.isLoaded) { f(null, entry.get); return }

    // now flatten out unloaded depends
     toLoad := flattenUnloadedDepends(Str[,], entry)

    // load each one async in order
    doLoadAsync(toLoad, 0, f)
  }

  private Void doLoadAsync(Str[] names, Int index, |Err?, Lib?| f)
  {
    // load from transport
    name := names[index]
    transport.loadLib(name) |err, lib|
    {
      // handle error
      if (err != null)
      {
        f(err, null)
        return
      }

      // update entry with the library instance
      entry := get(name)
      entry.set(lib)
      lib = entry.get

      // recursively load the next library in our flattened
      // depends list or if last one then invoke the callback
      index++
      if (index < names.size)
        doLoadAsync(names, index, f)
      else
        f(null, lib)
    }
  }

  Str[] flattenUnloadedDepends(Str[] acc, RemoteRegistryEntry entry)
  {
    entry.depends.each |dependName|
    {
      // if dependency is already loaded or already in our load list skip it
      depend := get(dependName)
      if (depend.isLoaded || acc.contains(depend.name)) return

      // recursively get its unloaded dependencies
      flattenUnloadedDepends(acc, depend)
    }
    acc.add(entry.name)
    return acc
  }

  override Int build(LibRegistryEntry[] libs)
  {
    throw UnsupportedErr()
  }

  const XetoTransport transport
  override const RemoteRegistryEntry[] list
  const Str:RemoteRegistryEntry map
}

**************************************************************************
** RemoteRegistryEntry
**************************************************************************

@Js
internal const class RemoteRegistryEntry : MRegistryEntry
{
  new make(Str name, Str[] depends)
  {
    this.name = name
    this.depends = depends
  }

  override const Str name

  const Str[] depends   // depends library names

  override Version version() { Version.defVal }

  override Str doc() { "" }

  override Str toStr() { name }

  override File zip() { throw UnsupportedErr() }

  override Bool isSrc() { false }

  override File? srcDir(Bool checked := true) { throw UnsupportedErr() }

}

