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
using haystack

**
** RemoteLoader is used to load a library serialized over a network
**
@Js
internal class RemoteLoader
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MEnv env, Str libName, Dict libMeta, Int flags)
  {
    this.env        = env
    this.libName    = libName
    this.libMeta    = libMeta
    this.libVersion = libMeta->version
    this.flags      = flags
  }

//////////////////////////////////////////////////////////////////////////
// Top
//////////////////////////////////////////////////////////////////////////

  XetoLib loadLib()
  {
    loadBindings

    depends := libMeta["depends"] ?: MLibDepend#.emptyList
    tops    := loadTops

    m := MLib(loc, libName, libMeta, flags, libVersion, depends, tops, instances, UnsupportedLibFiles.val)
    XetoLib#m->setConst(lib, m)
    return lib
  }

  RSpec addTop(Str name)
  {
    x := RSpec(libName, null, name)
    tops.add(name, x)
    return x
  }

  RSpec makeSlot(RSpec parent, Str name)
  {
    x := RSpec(libName, parent, name)
    return x
  }

  Void addInstance(Dict x)
  {
    id := x.id.id
    name := id[id.index(":")+2..-1]
    instances.add(name, x)
  }

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  private Void loadBindings()
  {
    // check if this library registers a new factory loader
    if (bindings.needsLoad(libName, libVersion))
    {
      this.bindingLoader = bindings.load(libName, libVersion)
    }
  }

  private SpecBinding assignBinding(RSpec x)
  {
    // check for custom factory if x is a type
    b := bindings.forSpec(x.qname)
    if (b != null) return b

    // route to loader for this spec
    // NOTE: relies that x.base is already bound in inheritance order
    if (bindingLoader != null)
    {
      b = bindingLoader.loadSpec(bindings, x)
      if (b != null) return b
    }

    // try use base type's binding
    b = x.base?.binding
    if (b != null) return b

    // last case fallback to dict/scalar factory
    isScalar := MSpecFlags.scalar.and(x.flags) != 0
    return isScalar ? GenericScalarBinding(x.qname) : bindings.dict
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  private Str:XetoSpec loadTops()
  {
    tops.map |x->XetoSpec| { loadSpec(x).asm }
  }

  private RSpec loadSpec(RSpec x)
  {
    if (x.isLoaded) return x

    x.isLoaded = true
    x.base     = resolve(x.baseIn)
    x.metaOwn  = resolveMeta(x.metaOwnIn)

    if (x.base == null)
    {
      // sys::Obj
      x.meta       = x.metaOwn
      x.slotsOwn   = loadSlotsOwn(x.slotsOwnIn)
      x.globalsOwn = loadSlotsOwn(x.globalsOwnIn)
      x.slots      = x.slotsOwn
    }
    else
    {
      // recursively load base and inherit
      if (x.base.isAst) loadSpec(x.base)
      x.meta       = inheritMeta(x)
      x.slotsOwn   = loadSlotsOwn(x.slotsOwnIn)
      x.globalsOwn = loadSlotsOwn(x.globalsOwnIn)
      x.slots      = inheritSlots(x)
      x.args       = loadArgs(x)
    }

    if (x.flavor.isType) x.bindingRef = assignBinding(x)

    init := MSpecInit {
      it.loc        = this.loc
      it.lib        = this.lib
      it.parent     = x.parent?.asm
      it.qname      = this.qname(x)
      it.type       = this.type(x)
      it.name       = x.name
      it.base       = x.base?.asm
      it.meta       = x.meta
      it.metaOwn    = x.metaOwn
      it.slots      = x.slots
      it.slotsOwn   = x.slotsOwn
      it.globalsOwn = x.globalsOwn
      it.flags      = x.flags
      it.args       = x.args
      it.binding    = x.bindingRef
    }

    MSpec? m
    if (x.flavor.isType)
    {
      //x.bindingRef = assignBinding(x)
      //m = MType(loc, lib, qname(x), x.name, x.base?.asm, x.asm, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args, x.binding)
      m = MType(init)
    }
    else if (x.flavor.isMixin)
    {
      //m = MMixin(loc, lib, qname(x), x.name, x.base.asm, x.base.asm, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args)
      m = MMixin(init)
    }
    else if (x.flavor.isFunc)
    {
      //m = MTopFunc(loc, lib, qname(x), x.name, x.base.asm, x.base.asm, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args)
      m = MTopFunc(init)
    }
    else if (x.flavor.isMeta)
    {
      // m = MMetaSpec(loc, lib, qname(x), x.name, x.base.asm, x.base.asm, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args)
      m = MMetaSpec(init)
    }
    else
    {
      //x.type = (XetoSpec)resolve(x.typeIn).asm
      //m = MSpec(loc, x.parent.asm, x.name, x.base.asm, x.type, x.meta, x.metaOwn, x.slots, x.slotsOwn, x.flags, x.args)
      m = MSpec(init)
    }
    XetoSpec#m->setConst(x.asm, m)
    return x
  }

  private Str? qname(RSpec x)
  {
    if (x.flavor.isSlot) return null
    return StrBuf(libName.size + 2 + x.name.size).add(libName).addChar(':').addChar(':').add(x.name).toStr
  }

  private XetoSpec type(RSpec x)
  {
    if (x.flavor.isType) return x.asm
    if (x.typeIn != null) return resolve(x.typeIn).asm
    return x.base.asm
  }

  private Dict resolveMeta(Dict m)
  {
    // resolve spec ref values
    return m.map |v, n|
    {
      v is RSpecRef ? resolve(v).asm : v
    }
  }

  private SpecMap loadSlotsOwn(RSpec[]? slots)
  {
    // short circuit if no slots
    if (slots == null || slots.isEmpty) return MSpecMap.empty

    // recursively load slot specs
    slots.each |slot| { loadSpec(slot) }

    // buid assembled map
    map := Str:XetoSpec[:]
    map.ordered = true
    slots.each |slot| { map.add(slot.name, slot.asm) }
    return SpecMap(map)
  }

  private Dict inheritMeta(RSpec x)
  {
    // if we included effective meta from compound types use it
    if (x.metaIn != null) return resolveMeta(x.metaIn)

    own     := x.metaOwn         // my own meta
    base    := x.base.cmeta      // base spec meta
    inherit := x.metaInheritedIn // names to inherit from base

    // optimize when we can just reuse base
    if (own.isEmpty)
    {
      baseSize := 0
      base.each |v| { baseSize++ }
      if (baseSize == inherit.size) return base
    }

    // create effective meta from inherited names from base and my own
    acc := Str:Obj[:]
    inherit.each |n| { acc[n] = base.trap(n) }
    XetoUtil.addOwnMeta(acc, own)

    return Etc.dictFromMap(acc)
  }

  private SpecMap inheritSlots(RSpec x)
  {
    // if we encoded inherited refs for and/or types, then use that
    if (x.slotsInheritedIn != null)
      return inheritSlotsFromRefs(x)

    // if my own slots are empty, I can just reuse my parent's slot map
    base := x.base
    if (x.slotsOwn.isEmpty)
    {
      if (base.isAst)
        return ((RSpec)base).slots ?: MSpecMap.empty // TODO: recursive base problem
      else
        return ((XetoSpec)base).m.slots
    }

    // simple single base class solution
    acc := Str:XetoSpec[:]
    acc.ordered = true

    autoCount := 0
    x.base.cslots |slot|
    {
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = XetoUtil.autoName(autoCount++)
      if (acc[name] == null) acc[name] = slot.asm
    }
    x.slotsOwn.each |slot|
    {
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = XetoUtil.autoName(autoCount++)
      acc[name] = slot
    }
    return SpecMap(acc)
  }

  private SpecMap inheritSlotsFromRefs(RSpec x)
  {
    acc := Str:XetoSpec[:]
    acc.ordered = true
    x.slotsInheritedIn.each |ref|
    {
      slot := resolve(ref)
      if (slot.isAst) loadSpec(slot)
      if (acc[slot.name] == null) acc[slot.name] = slot.asm
    }
    x.slotsOwn.each |slot|
    {
      acc[slot.name] = slot
    }
    return SpecMap(acc)
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
    rref := RSpecRef(libName, specName, "", null)
    return resolve(rref).asm
  }

//////////////////////////////////////////////////////////////////////////
// Resolve
//////////////////////////////////////////////////////////////////////////

  private CSpec? resolve(RSpecRef? ref)
  {
    if (ref == null) return null
    if (ref.lib == libName)
      return resolveInternal(ref)
    else
      return resolveExternal(ref)
  }

  private CSpec resolveInternal(RSpecRef ref)
  {
    // resolve type level
    type := tops.getChecked(ref.type)
    if (ref.slot.isEmpty) return type

    // resolve slot level (may be globals too if we inherit from global)
    // TODO: this might need to get mapped into hash map
    slot := type.slotsOwnIn?.find |s| { s.name == ref.slot }
    if (slot == null) slot = type.globalsOwnIn?.find |s| { s.name == ref.slot }
    if (slot == null) throw UnresolvedErr(ref.toStr)
    if (ref.more == null) return slot

    x := slot
    ref.more.each |more|
    {
      x = x.slotsOwnIn.find |s| { s.name == more } ?: throw UnresolvedErr(ref.toStr)
    }
    return x
  }

  private XetoSpec resolveExternal(RSpecRef ref)
  {
    // should already be loaded
    lib := env.get(ref.lib)
    type := (XetoSpec)lib.spec(ref.type)
    if (ref.slot.isEmpty) return type

    slot := type.member(ref.slot, false) ?: throw UnresolvedErr(ref.toStr)
    if (ref.more == null) return slot

    throw Err("TODO: $type $ref")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MEnv env
  const FileLoc loc := FileLoc("remote")
  const XetoLib lib := XetoLib()
  const Str libName
  const Dict libMeta
  const Version libVersion
  const Int flags
  private Str:RSpec tops := [:]              // addTops
  private Str:Dict instances := [:]          // addInstance (unreified)
  private const SpecBindings bindings := SpecBindings.cur
  private SpecBindingLoader? bindingLoader
}

