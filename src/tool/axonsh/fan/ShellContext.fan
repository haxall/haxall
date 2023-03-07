//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2023  Brian Frank  Creation
//

using data
using haystack
using axon

**
** Shell context
**
internal class ShellContext : AxonContext
{
  new make(ShellSession session)
  {
    this.session = session
    this.data = DataEnv.cur
    this.funcs = loadFuncs

    importDataLib("sys")
    importDataLib("ph")
  }

  static Str:TopFn loadFuncs()
  {
    acc := Str:TopFn[:]
    acc.addAll(FantomFn.reflectType(CoreLib#))
    acc.addAll(FantomFn.reflectType(ShellFuncs#))
    acc.addAll(FantomFn.reflectType(ShellDbFuncs#))
    return acc
  }

  ShellSession session

  OutStream out() { session.out }

  ShellDb db() { session.db }

  const /*override*/ DataEnv data

  const Str:TopFn funcs

  Str:DataLib libs := [:]

  override Namespace ns()
  {
    throw Err("TODO")
  }

  //override DataLib[] dataLibs() { libs.vals }

  /*
  override DataType? findType(Str name, Bool checked := true)
  {
    acc := DataType[,]
    libs.each |lib| { acc.addNotNull(lib.libType(name, false)) }
    if (acc.size == 1) return acc[0]
    if (acc.size > 1) throw Err("Ambiguous types for '$name' $acc")
    if (checked) throw UnknownTypeErr(name)
    return null
  }
  */

  override Fn? findTop(Str name, Bool checked := true)
  {
    f := funcs[name]
    if (f != null) return f
    if (checked) throw UnknownFuncErr(name)
    return null
  }

  /*
  override Dict[] readAll(Filter filter)
  {
    db.readAllList(filter, Etc.emptyDict, this)
  }
  */

  override Dict? deref(Ref id)
  {
    db.readById(id, false)
  }

  override Dict? trapRef(Ref ref, Bool checked := true)
  {
    db.readById(ref, checked)
  }

  override FilterInference inference()
  {
    throw Err("TODO")
  }

  override Dict toDict()
  {
    Etc.makeDict(["shell":Marker.val])
  }

  DataLib importDataLib(Str qname)
  {
    lib := libs[qname]
    if (lib == null)
    {
      libs[qname] = lib = data.lib(qname)
    }
    return lib
  }

  File resolveFile(Uri uri)
  {
    File(uri, false)
  }

}