//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Aug 2022  Brian Frank  Creation
//

using util
using concurrent
using xeto
using haystack::Dict

**
** RemoteLoader is used to load a library serialized over a network
**
@Js
internal class RemoteLoader
{
  new make(RemoteEnv env, Int libNameCode, NameDict libMeta)
  {
    this.env         = env
    this.names       = env.names
    this.libName     = names.toName(libNameCode)
    this.libNameCode = libNameCode
    this.libMeta     = libMeta
  }

  XetoLib loadLib()
  {
    version   := Version.fromStr((Str)libMeta->version)
    depends   := MLibDepend[,] // TODO: from meta
    types     := loadTypes
    instances := loadInstances

    m := MLib(env, loc, libNameCode, MNameDict(libMeta), version, depends, types, instances)
    XetoLib#m->setConst(lib, m)
    return lib
  }

  private Str:XetoType loadTypes()
  {
    types.map |x->XetoType| { loadSpec(x) }
  }

  private XetoSpec loadSpec(RemoteLoaderSpec x)
  {
    isType := x.type == null

    name     := x.name
    qname    := StrBuf(libName.size + 2 + name.size).add(libName).addChar(':').addChar(':').add(name).toStr
echo("## load type: $qname")
    type     := isType ? x.spec : resolve(x.type)
    base     := resolve(x.base)
    metaOwn  := x.metaOwn
    meta     := metaOwn // TODO
    slots    := MSlots.empty // TODO
    slotsOwn := MSlots.empty // TODO
    flags    := x.flags
    factory  := env.factories.dict // TODO

    m := MType(loc, env, lib, qname, x.nameCode, base, type, MNameDict(meta), MNameDict(metaOwn), slots, slotsOwn, flags, factory)
    XetoSpec#m->setConst(x.spec, m)
    return type
  }

  private XetoSpec? resolve(RemoteLoaderSpecRef? ref)
  {
    if (ref == null) return null
    if (ref.lib == libNameCode)
      return resolveInternal(ref)
    else
      return resolveExternal(ref)
  }

  private XetoSpec resolveInternal(RemoteLoaderSpecRef ref)
  {
    type := types.getChecked(names.toName(ref.type))
    if (ref.slot == 0) return type.spec

    throw Err("TODO: $ref")
  }

  private XetoSpec resolveExternal(RemoteLoaderSpecRef ref)
  {
    throw Err("TODO")
  }

  private Str:Dict loadInstances()
  {
    Str:Dict[:]
  }

  RemoteLoaderSpec addType(Int nameCode)
  {
    name := names.toName(nameCode)
    x := RemoteLoaderSpec(XetoType(), nameCode, name)
    types.add(name, x)
    return x
  }

  const RemoteEnv env
  const NameTable names
  const FileLoc loc := FileLoc("remote")
  const XetoLib lib := XetoLib()
  const Str libName
  const Int libNameCode
  const NameDict libMeta
  Str:RemoteLoaderSpec types := [:]
  Str:NameDict instances := [:]
}

**************************************************************************
** RemoteLoaderSpec
**************************************************************************

@Js
internal class RemoteLoaderSpec
{
  new make(XetoSpec spec, Int nameCode, Str name)
  {
    this.spec = spec
    this.nameCode = nameCode
    this.name = name
  }

  const XetoSpec spec
  const Int nameCode
  const Str name
  RemoteLoaderSpecRef? type
  RemoteLoaderSpecRef? base
  NameDict? metaOwn
  RemoteLoaderSpec[]? slotsOwn
  Int flags
}

**************************************************************************
** RemoteLoaderSpecRef
**************************************************************************

@Js
internal class RemoteLoaderSpecRef
{
  Int lib       // lib name
  Int type      // top-level type name code
  Int slot      // first level slot or zero if type only
  Int[]? more   // slot path below first slot (uncommon)

  override Str toStr() { "$lib $type $slot $more" }
}



