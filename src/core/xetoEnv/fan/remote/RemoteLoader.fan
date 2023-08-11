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

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(RemoteEnv env, Int libNameCode, NameDict libMeta)
  {
    this.env         = env
    this.names       = env.names
    this.libName     = names.toName(libNameCode)
    this.libNameCode = libNameCode
    this.libMeta     = libMeta
  }

//////////////////////////////////////////////////////////////////////////
// Top
//////////////////////////////////////////////////////////////////////////

  XetoLib loadLib()
  {
    loadFactories

    version   := Version.fromStr((Str)libMeta->version)
    depends   := loadDepends
    types     := loadTypes
    instances := loadInstances

    m := MLib(env, loc, libNameCode, MNameDict(libMeta), version, depends, types, instances)
    XetoLib#m->setConst(lib, m)
    return lib
  }

  RemoteLoaderSpec addType(Int nameCode)
  {
    name := names.toName(nameCode)
    x := RemoteLoaderSpec(XetoType(), null, nameCode, name)
    types.add(name, x)
    return x
  }

  RemoteLoaderSpec makeSlot(RemoteLoaderSpec parent, Int nameCode)
  {
    name := names.toName(nameCode)
    x := RemoteLoaderSpec(XetoSpec(), parent, nameCode, name)
    return x
  }

//////////////////////////////////////////////////////////////////////////
// Lib Depends
//////////////////////////////////////////////////////////////////////////

  private MLibDepend[] loadDepends()
  {
    obj := libMeta["depends"]
    if (obj == null) return MLibDepend#.emptyList
    list := (NameDict)obj

    acc := MLibDepend[,]
    acc.capacity = list.size
    list.each |NameDict x|
    {
      name := x->lib
      vers := MLibDependVersions(x->versions.toStr, true)
      acc.add(MLibDepend(name, vers, loc))
    }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  private Void loadFactories()
  {
    // find a loader for our library
    loader := env.factories.loaders.find |x| { x.canLoad(libName) }
    if (loader == null) return

    // if we have a loader, give it my type names to map to factories
    factories = loader.load(libName, types.keys)
  }

  private SpecFactory assignFactory(RemoteLoaderSpec x)
  {
    // check for custom factory if x is a type
    if (x.isType)
    {
      custom := factories?.get(x.name)
      if (custom != null)
      {
        env.factories.map(custom.type, x.spec)
        return custom
      }
    }

    // fallback to dict/scalar factory
    isScalar := MSpecFlags.scalar.and(x.flags) != 0
    return isScalar ? env.factories.scalar : env.factories.dict
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  private Str:XetoType loadTypes()
  {
    types.map |x->XetoType| { loadSpec(x) }
  }

  private XetoSpec loadSpec(RemoteLoaderSpec x)
  {
    parent   := x.parent?.spec
    name     := x.name
    qname    := StrBuf(libName.size + 2 + name.size).add(libName).addChar(':').addChar(':').add(name).toStr
    type     := x.isType ? x.spec : resolve(x.type)
    base     := resolve(x.base)
    metaOwn  := loadMetaOwn(x.metaOwn)
    meta     := metaOwn // TODO
    slotsOwn := loadSlots(x)
    slots    := slotsOwn

    MSpec? m
    if (x.isType)
    {
      factory  := assignFactory(x)
      m = MType(loc, env, lib, qname, x.nameCode, base, type, MNameDict(meta), MNameDict(metaOwn), slots, slotsOwn, x.flags, factory)
    }
    else
    {
      m = MSpec(loc, env, parent, x.nameCode, base, type, MNameDict(meta), MNameDict(metaOwn), slots, slotsOwn, x.flags)
    }
    XetoSpec#m->setConst(x.spec, m)
    return x.spec
  }

  private NameDict loadMetaOwn(NameDict meta)
  {
    // short circuit on empty
    if (meta.isEmpty) return meta

    // resolve ref values
    return meta.map |v, n|
    {
      v is RemoteLoaderSpecRef ? resolve(v) : v
    }
  }

  private MSlots loadSlots(RemoteLoaderSpec x)
  {
    // short circuit if no slots
    slots := x.slotsOwn
    if (slots == null || slots.isEmpty) return MSlots.empty

    // recursively load slot specs
    slots.each |slot| { loadSpec(slot) }

    // RemoteLoaderSpec is a NameDictReader to iterate slots as NameDict
    dict := names.readDict(slots.size, x, null)
    return MSlots(dict)
  }

//////////////////////////////////////////////////////////////////////////
// Resolve
//////////////////////////////////////////////////////////////////////////

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
    // should already be loaded
    lib := env.lib(names.toName(ref.lib))
    type := lib.type(names.toName(ref.type))
    if (ref.slot == 0) return type

    throw Err("TODO: $type $ref")
  }

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  private Str:Dict loadInstances()
  {
    Str:Dict[:]
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const RemoteEnv env
  const NameTable names
  const FileLoc loc := FileLoc("remote")
  const XetoLib lib := XetoLib()
  const Str libName
  const Int libNameCode
  const NameDict libMeta
  private Str:RemoteLoaderSpec types := [:]   // addType
  private Str:NameDict instances := [:]       // addInstance
  private [Str:SpecFactory]? factories        // loadFactories
}

**************************************************************************
** RemoteLoaderSpec
**************************************************************************

@Js
internal class RemoteLoaderSpec : NameDictReader
{
  new make(XetoSpec spec, RemoteLoaderSpec? parent, Int nameCode, Str name)
  {
    this.spec     = spec
    this.parent   = parent
    this.nameCode = nameCode
    this.name     = name
  }

  const XetoSpec spec
  const Int nameCode
  const Str name
  RemoteLoaderSpec? parent { private set }

  Bool isType() { type == null }
  Bool isScalar() { hasFlag(MSpecFlags.scalar) }
  Bool hasFlag(Int mask) { flags.and(mask) != 0 }

  RemoteLoaderSpecRef? base
  RemoteLoaderSpecRef? type
  NameDict? metaOwn
  RemoteLoaderSpec[]? slotsOwn
  Int flags

  override Int readName() { slotsOwn[readIndex].nameCode }
  override Obj readVal() { slotsOwn[readIndex++].spec }
  Int readIndex

  override Str toStr() { name }
}

**************************************************************************
** RemoteLoaderSpecRef
**************************************************************************

@Js
internal const class RemoteLoaderSpecRef
{
  new make(Int lib, Int type, Int slot, Int[]? more)
  {
    this.lib  = lib
    this.type = type
    this.slot = slot
    this.more = more
  }

  const Int lib       // lib name
  const Int type      // top-level type name code
  const Int slot      // first level slot or zero if type only
  const Int[]? more   // slot path below first slot (uncommon)

  override Str toStr() { "$lib $type $slot $more" }
}



