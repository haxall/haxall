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

  static Comp create(CompSpace cs, Dict dict)
  {
    process(cs) { it.doCreate(dict) }
  }

  static CompSpi initSpi(CompSpace cs, CompObj c, Spec? spec)
  {
    process(cs) { it.doInitSpi(c, spec) }
  }

  private static Obj? process(CompSpace cs, |This->Obj?| f)
  {
    actorKey := "xetoEnv::csf"

    // if already inside a factory then resuse it
    cur := Actor.locals.get(actorKey)
    if (cur != null) return f(cur)

    // new top-level factory call
    cur = make(cs)
    Actor.locals.set(actorKey, cur)
    Obj? res
    try
      res = f(cur)
    finally
      Actor.locals.remove(actorKey)
    return res
  }

//////////////////////////////////////////////////////////////////////////
// Implementation
//////////////////////////////////////////////////////////////////////////

  private new make(CompSpace cs)
  {
    this.cs = cs
    this.ns = cs.ns
    this.compSpec = cs.ns.lib("sys.comp").spec("Comp")
  }

  private Comp doCreate(Dict dict)
  {
    spec := cs.ns.spec(dict->spec.toStr)
    return reifyComp(spec, dict)
  }

  private CompSpi doInitSpi(CompObj c, Spec? spec)
  {
    // check if we stashed spec/slots for this instance
    init := curCompInit
    if (init != null) spec = init.spec

    // infer spec from type if not passed in
    if (spec == null) spec = ns.specOf(c)

    // create default slots for component
    [Str:Comp]? children := null
    acc := Str:Obj[:]
    acc.ordered = true
    acc["id"] = genId

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
    this.curCompInit = null
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

  private haystack::Ref genId() { cs.genId }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Spec compSpec
  private const LibNamespace ns
  private CompSpace cs
  private CompSpiInit? curCompInit
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
}

