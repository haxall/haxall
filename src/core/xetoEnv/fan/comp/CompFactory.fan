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
** CompFactory is used to create Comp and CompSpi instances
**
@Js
internal class CompFactory
{
  new make(CompSpace cs)
  {
    this.cs = cs
    this.compSpec = cs.ns.lib("sys.comp").spec("Comp")
  }

  Comp create(Dict dict)
  {
    spec := cs.ns.spec(dict->spec.toStr)
    return reifyComp(spec, dict)
  }

  CompSpi initSpi(CompObj c, Spec? spec)
  {
    // check if we stashed spec/slots for this instance
    init := Actor.locals.remove(spiInitActorKey) as CompSpiInit
    if (init != null) spec = init.spec

    // infer spec from type if not passed in
    if (spec == null) spec = ns.specOf(c)

    // create default slots for component
    [Str:Comp]? children := null
    acc := Str:Obj[:]
    acc.ordered = true
    acc["id"] = genId
    Dict slots := init?.slots ?: ns.instantiate(spec)
    slots.each |v, n|
    {
      // skip
      if (n == "id" || n == "compName") return

      // reify dict value to value to store as actual comp slot
      v = reify(v)

      // if slot is child comp, we need to keep track
      if (v is Comp)
      {
        if (children == null) children = Str:Comp[:]
        children[n] = v
      }

      // add this to our default slots
      acc.add(n, v)
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

  private Obj reify(Obj v)
  {
    // check if we have a dict with a Comp spec
    dict := v as Dict;                  if (dict == null) return v
    specRef := dict["spec"] as Ref;     if (specRef == null) return v
    spec := ns.spec(specRef.id, false); if (spec == null) return v
    if (!spec.isa(compSpec)) return v

    // need to reify this value as a Comp instance
    return reifyComp(spec, dict)
  }

  private Comp reifyComp(Spec spec, Dict slots)
  {
    Actor.locals[spiInitActorKey] = CompSpiInit(spec, slots)
    return toFantomType(spec).make
  }

  private Type toFantomType(Spec spec)
  {
    // TODO: this should never default to Dict
    t := spec.fantomType
    if (t == xeto::Dict# || t == Comp#) return CompObj#
    if (t.isMixin) return t.pod.type(t.name + "Obj")
    return t
  }

  private haystack::Ref genId()
  {
    compCounter++
    return haystack::Ref(""+compCounter)
  }

  private LibNamespace ns() { cs.ns }

  private const static Str spiInitActorKey := "compSpiInit"

  private const Spec compSpec
  private CompSpace cs
  private Int compCounter := 0
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

