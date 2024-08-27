//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 May 2024  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using haystack::Dict
using haystack::Ref

**
** CompFactory is a temporary object used to create a swizzled
** graph of components and their SPIs.
**
@Js
internal class CompFactory
{

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Create new list of components from a dicts
  static Comp[] create(CompSpace cs, Dict[] dicts)
  {
    process(cs) |cf, isTop|{ cf.doCreate(dicts, isTop) }
  }

  ** Create the SPI for given component. This is called by
  ** the CompObj constructor thru CompSpace actor local
  static CompSpi initSpi(CompSpace cs, CompObj c, Spec? spec)
  {
    process(cs) |cf, isTop| { cf.doInitSpi(c, spec, isTop) }
  }

  ** Process a graph operation with single instance via actor local
  private static Obj? process(CompSpace cs, |This,Bool->Obj?| f)
  {
    actorKey := "xetoEnv::cf"

    // if already inside a factory operation then resuse it
    cur := Actor.locals.get(actorKey)
    if (cur != null) return f(cur, false)

    // new top-level factory call
    cur = make(cs)
    Actor.locals.set(actorKey, cur)
    Obj? res
    try
      res = f(cur, true)
    finally
      Actor.locals.remove(actorKey)
    return res
  }

  ** Private constructor
  private new make(CompSpace cs)
  {
    this.cs = cs
    this.ns = cs.ns
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  private Comp[] doCreate(Dict[] dicts, Bool isTop)
  {
    // swizzle ids if at top-level
    if (isTop) dicts.each |dict| { swizzleInit(dict) }

    // map dict to spec
    return dicts.map |dict->Comp|
    {
      // reuse normal reifyComp code path
      spec := cs.ns.spec(dict->spec.toStr)
      return reifyComp(spec, dict)
    }
  }

  private CompSpi doInitSpi(CompObj c, Spec? spec, Bool isTop)
  {
    // check if we stashed spec/slots for this instance
    init := curCompInit
    curCompInit = null
    if (init != null) spec = init.spec

    // swizzle ids if at top-level
    if (isTop && init != null) swizzleInit(init.slots)

    // infer spec from type if not passed in
    if (spec == null) spec = ns.specOf(c)

    // create default slots for component
    [Str:Comp]? children := null
    acc := Str:Obj[:]
    acc.ordered = true
    acc["id"] = newId(init?.slots)

    // first fill in with default slot values
    children = initSlots(spec, acc, children, ns.instantiate(spec))

    // overwrite with slots passed in
    if (init != null) children = initSlots(spec, acc, children, init.slots)

    // reify functions that map to methods
    spec.slots.each |slot|
    {
      name := slot.name
      if (!slot.isFunc || acc[name] != null) return
      method := CompUtil.toHandlerMethod(c, slot)
      if (method != null) acc[name] = FantomMethodCompFunc(method)
    }

    // create spi
    spi := MCompSpi(cs, c, spec, acc)

    // now wire up parent/child relationships
    if (children != null)
    {
      children.each |kid, name| { spi.addChild(name, kid) }
    }

    return spi
  }

  private [Str:Comp]? initSlots(Spec spec, Str:Obj acc, [Str:Comp]? children, Dict slots)
  {
    slots.each |v, n|
    {
      // skip
      if (n == "id" || n == "compName") return

      // get spec slot
      slot := spec.slot(n, false)

      // reify dict value to value to store as actual comp slot
      v = reify(slot, v)

      // if slot is child comp, we need to keep track
      if (v is Comp)
      {
        if (children == null) children = Str:Comp[:]
        children[n] = v
      }

      // add this to our default slots
      acc[n] = v
    }

    return children
  }

//////////////////////////////////////////////////////////////////////////
// Id Generation & Swizzling
//////////////////////////////////////////////////////////////////////////

  ** Top-level init to swizzle a graph of dicts to map old ids to new ids.
  private Void swizzleInit(Dict dict)
  {
    // check if dict has old id
    oldId := dict["id"] as Ref
    if (oldId == null) return

    // lazily create swizzle map
    if (swizzleMap == null) swizzleMap = Ref:Ref[:]

    // create swizzled mapping
    newId := genId
    swizzleMap[oldId] = newId

    // recurse
    dict.each |v, n|
    {
      if (v is Dict) swizzleInit(v)
    }
  }

  ** Generate new id for given slots dict.  If we have previously
  ** swizzled the old id during top-level processing then return swizzled
  ** mapping, otherwise generate a fresh id
  private Ref newId(Dict? dict)
  {
    if (swizzleMap != null && dict != null)
    {
      oldId := dict["id"] as Ref
      if (oldId != null)
      {
        newId := swizzleMap[oldId]
        if (newId != null) return newId
      }
    }
    return genId
  }

  ** Given a non-id ref tag value, check if we need to swizzle id
  private Ref swizzleRef(Ref ref)
  {
    swizzleMap?.get(ref) ?: ref
  }

  ** Generate a fresh new id for a component
  private haystack::Ref genId()
  {
    cs.genId
  }

//////////////////////////////////////////////////////////////////////////
// Reify
//////////////////////////////////////////////////////////////////////////

  private Obj reify(Spec? slot, Obj v)
  {
    // check for scalar slot - this might need to happen instantiate
    if (slot != null && slot.isScalar && v is Str)
      return slot.factory.decodeScalar(v)

    // check if we have a dict with a Comp spec
    dict := v as Dict
    if (dict != null)
    {
      spec := dictToSpec(dict)
      if (spec != null && spec.isa(compSpec))
      {
        return reifyComp(spec, dict)
      }
    }

    // return the instantiate value
    return v
  }

  private Comp reifyComp(Spec spec, Dict slots)
  {
    this.curCompInit = CompSpiInit(spec, slots)
    comp := toFantomType(spec).make
    return comp
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Spec? dictToSpec(Dict dict)
  {
    specRef := dict["spec"] as Ref
    if (specRef == null) return null
    return ns.spec(specRef.id, false)
  }

  private Type toFantomType(Spec spec)
  {
    // TODO: this should never default to Dict
    t := spec.fantomType
    if (t == xeto::Dict# || t == Comp#) return CompObj#
    if (t.isMixin) return t.pod.type(t.name + "Obj")
    return t
  }

  private once Spec compSpec()
  {
    cs.ns.lib("sys.comp").spec("Comp")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const LibNamespace ns
  private CompSpace cs
  private CompSpiInit? curCompInit
  private [Ref:Ref]? swizzleMap
}

**************************************************************************
** CompSpiInit
**************************************************************************

@Js
internal const class CompSpiInit
{
  new make(Spec spec, Dict slots) { this.spec = spec; this.slots = slots }
  const Spec spec
  const Dict slots
  override Str toStr() { "CompSpiInit { $spec }" }
}

