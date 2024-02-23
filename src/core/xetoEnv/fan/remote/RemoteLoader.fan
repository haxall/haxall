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
using haystack::Etc

**
** RemoteLoader is used to load a library serialized over a network
**
@Js
internal class RemoteLoader
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(RemoteEnv env, Int libNameCode, MNameDict libMeta)
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

    version   := libMeta->version
    depends   := loadDepends
    tops      := loadTops
    instances := this.instances

    m := MLib(env, loc, libNameCode, libMeta, version, depends, tops, instances)
    XetoLib#m->setConst(lib, m)
    return lib
  }

  RSpec addTop(Int nameCode)
  {
    name := names.toName(nameCode)
    x := RSpec(libName, XetoType(), null, nameCode, name)
    tops.add(name, x)
    return x
  }

  RSpec makeSlot(RSpec parent, Int nameCode)
  {
    name := names.toName(nameCode)
    x := RSpec(libName, XetoSpec(), parent, nameCode, name)
    return x
  }

  Void addInstance(Dict x)
  {
    id := x.id.id
    name := id[id.index(":")+2..-1]
    instances.add(name, x)
  }

//////////////////////////////////////////////////////////////////////////
// Lib Depends
//////////////////////////////////////////////////////////////////////////

  private MLibDepend[] loadDepends()
  {
    obj := libMeta["depends"]
    if (obj == null) return MLibDepend#.emptyList
    list := (Obj?[])obj

    acc := MLibDepend[,]
    acc.capacity = list.size
    list.each |MNameDict x|
    {
      name := x->lib
      vers := MLibDependVersions.wildcard
      if (x.has("versions")) vers = MLibDependVersions(x->versions.toStr, true)
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
    factories = loader.load(libName, tops.keys)
  }

  private SpecFactory assignFactory(RSpec x)
  {
    // check for custom factory if x is a type
    if (x.isType)
    {
      custom := factories?.get(x.name)
      if (custom != null)
      {
        env.factories.map(custom.type, x.qname, x.asm)
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

  private Str:XetoSpec loadTops()
  {
    tops.map |x->XetoType| { loadSpec(x).asm }
  }

  private RSpec loadSpec(RSpec x)
  {
    if (x.isLoaded) return x

    x.isLoaded = true
    x.base     = resolve(x.baseIn)
    x.metaOwn  = loadMetaOwn(x)

    if (x.base == null)
    {
      // sys::Obj
      x.meta  = x.metaOwn
      x.slotsOwn = loadSlotsOwn(x)
      x.slots = x.slotsOwn
    }
    else
    {
      // recursively load base and inherit
      if (x.base.isAst) loadSpec(x.base)
      x.meta = inheritMeta(x)
      x.slotsOwn = loadSlotsOwn(x)
      x.slots = inheritSlots(x)
      x.args  = loadArgs(x)
    }

    MSpec? m
    if (x.isType)
    {
      factory := assignFactory(x)
      m = MType(loc, env, lib, qname(x), x.nameCode, x.base?.asm, x.asm, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args, factory)
    }
    else if (x.isGlobal)
    {
      m = MGlobal(loc, env, lib, qname(x), x.nameCode, x.base.asm, x.base.asm, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args)
    }
    else
    {
      x.type = resolve(x.typeIn).asm
      m = MSpec(loc, env, x.parent.asm, x.nameCode, x.base.asm, x.type, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args)
    }
    XetoSpec#m->setConst(x.asm, m)
    return x
  }

  private Str qname(RSpec x)
  {
    StrBuf(libName.size + 2 + x.name.size).add(libName).addChar(':').addChar(':').add(x.name).toStr
  }

  private MNameDict loadMetaOwn(RSpec x)
  {
    // short circuit on empty
    m := x.metaIn
    if (m.isEmpty) return MNameDict.empty

    // resolve spec ref values
    m = m.map |v, n|
    {
      v is RSpecRef ? resolve(v).asm : v
    }

    // wrap
    return MNameDict(m)
  }

  private MSlots loadSlotsOwn(RSpec x)
  {
    // short circuit if no slots
    slots := x.slotsIn
    if (slots == null || slots.isEmpty) return MSlots.empty

    // recursively load slot specs
    slots.each |slot| { loadSpec(slot) }

    // RSpec is a NameDictReader to iterate slots as NameDict
    dict := names.readDict(slots.size, x)
    return MSlots(dict)
  }

  private MNameDict inheritMeta(RSpec x)
  {
    if (x.metaOwn.isEmpty) return x.base.cmeta
    // TODO: I'm not sure AND/OR are merging meta
    return x.metaOwn
  }

  private MSlots inheritSlots(RSpec x)
  {
    base := x.base
    if (x.slotsOwn.isEmpty)
    {
      // TODO: this is type ref problem
      if (base === x.parent) return MSlots.empty

      if (base.isAst)
        return ((RSpec)base).slots ?: MSlots.empty // TODO: recursive base problem
      else
        return ((XetoSpec)base).m.slots
    }

    // TODO: just simple direct base class solution (not AND/OR)
    acc := Str:XetoSpec[:]
    acc.ordered = true
    x.base.cslots |slot|
    {
      if (acc[slot.name] == null) acc[slot.name] = slot.asm
    }
    x.slotsOwn.each |slot|
    {
      acc[slot.name] = slot
    }
    return MSlots(names.dictMap(acc))
  }

  private MSpecArgs loadArgs(RSpec x)
  {
    of := x.metaOwn["of"] as Ref
    if (of != null) return MSpecArgsOf(resolveRef(of))

    ofs := x.metaOwn["ofs"] as Ref[]
    if (ofs != null) return MSpecArgsOfs(ofs.map |ref->Spec| { resolveRef(ref) })

    return x.base.args
  }

  private Spec resolveRef(Ref ref)
  {
    // TODO: we can encode spec refs way better than a simple string
    // that has to get parsed again (see down below with RSpecRef)
    colons := ref.id.index("::")
    libName := ref.id[0..<colons]
    specName := ref.id[colons+2..-1]
    rref := RSpecRef(names.toCode(libName), names.toCode(specName), 0, null)
    return resolve(rref).asm
  }

//////////////////////////////////////////////////////////////////////////
// Resolve
//////////////////////////////////////////////////////////////////////////

  private CSpec? resolve(RSpecRef? ref)
  {
    if (ref == null) return null
    if (ref.lib == libNameCode)
      return resolveInternal(ref)
    else
      return resolveExternal(ref)
  }

  private CSpec resolveInternal(RSpecRef ref)
  {
    type := tops.getChecked(names.toName(ref.type))
    if (ref.slot == 0) return type

    slot := type.slotsIn.find |s| { s.nameCode == ref.slot } ?: throw UnresolvedErr(ref.toStr)
    if (ref.more == null) return slot

    throw Err("TODO: $ref")
  }

  private XetoSpec resolveExternal(RSpecRef ref)
  {
    // should already be loaded
    lib := env.lib(names.toName(ref.lib))
    type := (XetoSpec)lib.top(names.toName(ref.type))
    if (ref.slot == 0) return type

    slot := type.m.slots.map.getByCode(ref.slot) ?: throw UnresolvedErr(ref.toStr)
    if (ref.more == null) return slot

    throw Err("TODO: $type $ref")
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
  const MNameDict libMeta
  private Str:RSpec tops := [:]              // addTops
  private Str:Dict instances := [:]          // addInstance
  private [Str:SpecFactory]? factories       // loadFactories
}

