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
      loadSpecRef(x.baseIn)
RSpec? rbase
if (x.baseIn.slot.isEmpty && x.baseIn.lib == libName) rbase = tops.get(x.baseIn.type)
      x.meta       = inheritMeta(x, rbase)
      x.slotsOwn   = loadSlotsOwn(x.slotsOwnIn)
      x.globalsOwn = loadSlotsOwn(x.globalsOwnIn)
      x.slots      = inheritSlots(x, rbase)
      x.args       = loadArgs(x, rbase)
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

  private Void loadSpecRef(RSpecRef ref)
  {
    if (ref.lib == libName) loadSpec(tops.getChecked(ref.type))
  }

  private Str? qname(RSpec x)
  {
    if (x.flavor.isSlot) return null
    return StrBuf(libName.size + 2 + x.name.size).add(libName).addChar(':').addChar(':').add(x.name).toStr
  }

  private XetoSpec type(RSpec x)
  {
    if (x.flavor.isType) return x.asm
    if (x.typeIn != null) return resolve(x.typeIn)
    return x.base
  }

  private Dict resolveMeta(Dict m)
  {
    // resolve spec ref values
    return m.map |v, n|
    {
      v is RSpecRef ? resolve(v) : v
    }
  }

  private SpecMap loadSlotsOwn(RSpec[]? slots)
  {
    // short circuit if no slots
    if (slots == null || slots.isEmpty) return SpecMap.empty

    // recursively load slot specs
    slots.each |slot| { loadSpec(slot) }

    // buid assembled map
    map := Str:XetoSpec[:]
    map.ordered = true
    slots.each |slot| { map.add(slot.name, slot.asm) }
    return SpecMap(map)
  }

  private Dict inheritMeta(RSpec x, RSpec? rbase)
  {
    // if we included effective meta from compound types use it
    if (x.metaIn != null) return resolveMeta(x.metaIn)

    own     := x.metaOwn                   // my own meta
    base    := rbase?.meta ?: x.base.meta  // base spec meta
    inherit := x.metaInheritedIn           // names to inherit from base

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

  private SpecMap inheritSlots(RSpec x, RSpec? rbase)
  {
    // if we encoded inherited refs for and/or types, then use that
    if (x.slotsInheritedIn != null)
      return inheritSlotsFromRefs(x)

    // enum items don't have slots
    if (x.parent != null && x.parent.isEnum) return SpecMap.empty

    // if my own slots are empty, I can just reuse my parent's slot map
    baseSlots := rbase?.slots ?: x.base.slots
    if (x.slotsOwn.isEmpty) return baseSlots

    // simple single base class solution
    acc := Str:XetoSpec[:]
    acc.ordered = true

    autoCount := 0
    baseSlots.each |slot|
    {
      name := slot.name
      if (XetoUtil.isAutoName(name)) name = XetoUtil.autoName(autoCount++)
      if (acc[name] == null) acc[name] = slot
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
// TODO: we can optimize this
      loadSpecRef(ref)
      slot := resolve(ref)
      if (acc[slot.name] == null) acc[slot.name] = slot
    }
    x.slotsOwn.each |slot|
    {
      acc[slot.name] = slot
    }
    return SpecMap(acc)
  }

  private MSpecArgs loadArgs(RSpec x, RSpec? rbase)
  {
    of := x.metaOwn["of"] as Ref
    if (of != null) return MSpecArgsOf(resolveRef(of))

    ofs := x.metaOwn["ofs"] as Ref[]
    if (ofs != null) return MSpecArgsOfs(ofs.map |ref->Spec| { resolveRef(ref) })

    return rbase?.args ?: x.base.args
  }

  private Spec resolveRef(Ref ref)
  {
    // TODO: we can encode spec refs way better than a simple string
    // that has to get parsed again (see down below with RSpecRef)
    colons := ref.id.index("::")
    libName := ref.id[0..<colons]
    specName := ref.id[colons+2..-1]
    rref := RSpecRef(libName, specName, "", null)
    return resolve(rref)
  }

//////////////////////////////////////////////////////////////////////////
// Resolve
//////////////////////////////////////////////////////////////////////////

  private Spec? resolve(RSpecRef? ref)
  {
    if (ref == null) return null
    if (ref.lib == libName)
      return resolveInternal(ref)
    else
      return resolveExternal(ref)
  }

  private Spec resolveInternal(RSpecRef ref)
  {
    // resolve type level
    type := tops.getChecked(ref.type)
    if (ref.slot.isEmpty) return type.asm

    // resolve slot level (may be globals too if we inherit from global)
    // TODO: this might need to get mapped into hash map
    slot := type.slotsOwnIn?.find |s| { s.name == ref.slot }
    if (slot == null) slot = type.globalsOwnIn?.find |s| { s.name == ref.slot }
    if (slot == null) throw UnresolvedErr(ref.toStr)
    if (ref.more == null) return slot.asm

    x := slot
    ref.more.each |more|
    {
      x = x.slotsOwnIn.find |s| { s.name == more } ?: throw UnresolvedErr(ref.toStr)
    }
    return x.asm
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

