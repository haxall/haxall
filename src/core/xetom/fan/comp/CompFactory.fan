//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 May 2024  Brian Frank  Creation
//   15 Mar 2026  Brian Frank  Resign to use spec and link meta
//

using concurrent
using util
using xeto
using haystack

**
** CompFactory creates a comp or comp tree from a spec.
**
@Js
internal class CompFactory
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(MCompSpaceSpi csSpi)
  {
    this.csSpi = csSpi
    this.ns = csSpi.ns
  }

//////////////////////////////////////////////////////////////////////////
// Load
//////////////////////////////////////////////////////////////////////////

  ** Load comp tree from dict tree where we use ids directly
  Comp load(Dict dict, Spec? spec)
  {
    if (spec == null) spec = ns.spec(dict->spec.toStr)
    comp := create(spec)

    id := dict["id"] as Ref
    if (id != null) ((MCompSpi)comp.spi).setId(id)

    dict.each |v, n|
    {
      if (n == "id" || n == "spec") return
      x := reify(v)
      comp.set(n, x)
    }

    return comp
  }

  private Obj reify(Obj v)
  {
    dict := v as Dict
    specRef := dict?.get("spec")
    if (specRef != null)
    {
      spec := ns.spec(specRef.toStr, false)
      if (spec != null)
      {
        if (spec.isComp)
          return load(dict, spec)
        else
          return spec.binding.decodeDict(dict)
      }
    }
    return v
  }

//////////////////////////////////////////////////////////////////////////
// Create Dict
//////////////////////////////////////////////////////////////////////////

  ** Create from dict where we must swizzle ids
  Comp createFromDict(Dict dict)
  {
    load(swizzleIds(dict), null)
  }

  private Dict swizzleIds(Dict dict)
  {
    oldToNew := Ref:Ref[:]
    Etc.eachRef(dict) |id|
    {
      newId := id.id.contains("::") ? id : csSpi.genId
      oldToNew[id] = newId
    }

    return Etc.mapRefs(dict) |id| { oldToNew.getChecked(id) }
  }

//////////////////////////////////////////////////////////////////////////
// Create
//////////////////////////////////////////////////////////////////////////

  ** Create instance from spec
  Comp create(Spec spec)
  {
    locals := Actor.locals
    locals[actorKeyStub] = spec
    try
      return specToFantomType(spec).make
    finally
      locals.remove(actorKeyStub)
  }

  private Type specToFantomType(Spec spec)
  {
    // if there is no Fantom type registered this defaults
    // to Dict in which case walk up class hierarchy
    t := spec.fantomType
    if (t == xeto::Dict#) return specToFantomType(spec.base)
    if (t.isMixin) return t.pod.type(t.name + "Obj")
    return t
  }

  private Spec compToSpec(CompObj c)
  {
    spec := Actor.locals.remove(actorKeyStub) as Spec
    if (spec != null)
      return spec
    else
      return ns.specOf(c.typeof)
  }

  private static const Str actorKeyStub := "xetom.stub"

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

  ** Create CompSpi for given comp within its constructor
  MCompSpi init(CompObj comp)
  {
    // get stubbed spec or derive from type
    spec := compToSpec(comp)

    // build component slot map
    slots := Str:Obj[:]
    slots.ordered = true
    spec.slots.each |slot|
    {
      slots.addNotNull(slot.name, createSlot(slot))
    }

    return MCompSpi(csSpi, comp, csSpi.genId, spec, slots)
  }

  private Obj? createSlot(Spec slot)
  {
    if (slot.isFunc) return null
    if (slot.isMaybe && Instantiator.skipMaybe(slot)) return null
    if (slot.isComp) return createChild(slot)
    return ns.instantiate(slot)
  }

  private Comp createChild(Spec slot)
  {
    return create(slot)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private MCompSpaceSpi csSpi
  private Namespace ns
}

