//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 2025  Brian Frank  Pull out from XetoUtil
//

using util
using xeto
using haystack::Etc
using haystack::Kind
using haystack::Marker
using haystack::Number
using haystack::Ref
using haystack::Remove

**
** Instantiator implements LibNamespace.instantiate with support
** for templating, graph instantiate, and pluggable options
**
@Js
class Instantiator
{
  new make(MNamespace ns, Dict opts)
  {
    this.ns       = ns
    this.opts     = opts
    this.fidelity = XetoUtil.optFidelity(opts)
    this.parent   = opts["parent"] as Dict
  }

  ** Instantiate default value of spec
  Obj? instantiate(XetoSpec spec)
  {
    meta := spec.m.meta
    if (meta.has("abstract") && opts.missing("abstract")) throw Err("Spec is abstract: $spec.qname")

    if (spec.isNone) return null
    if (spec.type.isScalar) return instantiateScalar(ns, spec, opts)
    if (spec === ns.sys.dict) return Etc.dict0
    if (spec.isList) return instantiateList(ns, spec, opts)
    if (spec.isMultiRef) return Ref#.emptyList

    isGraph := opts.has("graph")

    acc := Str:Obj[:]
    acc.ordered = true

    id := opts["id"]
    if (id == null && isGraph) id = Ref.gen
    if (id != null) acc["id"] = id
    acc["spec"] = spec.type._id

    // add dis if not a dict slot
    isSlot := spec.parent != null && !spec.parent.isQuery
    if (!isSlot) acc["dis"] = XetoUtil.isAutoName(spec.name) ? spec.base.name : spec.name

    spec.slots.each |slot|
    {
      if (!instantiateSlot(slot)) return
      if (slot.name == "enum") return acc.setNotNull("enum", instantiateEnumDefault(slot))
      acc[slot.name] = instantiate(slot)
    }

    if (parent != null && parent["id"] is Ref)
    {
      // TODO: temp hack for equip/point common use case
      parentId := (Ref)parent["id"]
      if (parent.has("equip"))   acc["equipRef"] = parentId
      if (parent.has("site"))    acc["siteRef"]  = parentId
      if (parent.has("siteRef")) acc["siteRef"]  = parent["siteRef"]
    }

    dict := Etc.dictFromMap(acc)
    if (spec.binding.isDict)
      dict = spec.binding.decodeDict(dict)

    if (opts.has("graph"))
      return instantiateGraph(ns, spec, opts, dict)
    else
      return dict
  }

  private Bool instantiateSlot(Spec slot)
  {
    if (slot.isQuery)  return false
    if (slot.isFunc)   return false
    if (slot.isChoice) return false // TODO: not sure about this one...
    if (slot.isMaybe)
    {
      // the rule for maybe types is that slot definition
      // itself must define a default value
      ownMeta := slot.metaOwn
      if (slot.metaOwn.has("val"))
        return true
      else
        return false
    }
    if (slot.isRef)
    {
      // don't default non-null ref slots to Ref default value "x"
      val := slot.get("val") as Ref
      if (val?.id == "x") return false
    }
    return true
  }

  private Obj? instantiateEnumDefault(XetoSpec slot)
  {
    val := slot.get("val")
    if (val == null) return null
    if (val is Ref) return val
    s := val.toStr
    if (!s.isEmpty) return s
    return null
  }

  private List instantiateList(MNamespace ns, XetoSpec spec, Dict opts)
  {
    of := spec.of(false)
    listOf := of == null ? Obj# : of.fantomType
    if (of != null && of.isMaybe) listOf = of.base.fantomType.toNullable
    acc := List(listOf, 0)
    val := spec.meta["val"] as List
    if (val != null)
    {
      acc.capacity = val.size
      val.each |v|
      {
        acc.add(fidelity.coerce(v))
      }
    }
    return acc.toImmutable
  }

  private Obj instantiateScalar(MNamespace ns, XetoSpec spec, Dict opts)
  {
    x := spec.meta["val"] ?: spec.type.meta["val"]
    if (x == null) x = ""
    return fidelity.coerce(x)
  }

  private Dict[] instantiateGraph(MNamespace ns, XetoSpec spec, Dict opts, Dict dict)
  {
    oldParent := this.parent
    this.parent  = dict
    graph := Dict[,]
    graph.add(dict)

    // recursively add constrained query children
    spec.slots.each |slot|
    {
      if (!slot.isQuery) return
      if (slot.slots.isEmpty) return
      slot.slots.each |x|
      {
        kids := instantiate(x)
        if (kids isnot List) return
        graph.addAll(kids)
      }
    }

    this.parent = oldParent

    return graph
  }

  const MNamespace ns
  const Dict opts
  const XetoFidelity fidelity
  Dict? parent
}

