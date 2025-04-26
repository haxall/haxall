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
    this.isGraph  = opts.has("graph")
  }

  ** Instantiate default value of spec
  Obj? instantiate(XetoSpec spec)
  {
    // input checks
    checks(spec)

    // handle non-dict types
    if (spec.isNone)          return null
    if (spec.type.isScalar)   return scalar(spec, opts)
    if (spec.isList)          return list(spec, opts)
    if (spec.isMultiRef)      return Ref#.emptyList
    if (spec === ns.sys.dict) return Etc.dict0

    // build up dict tags
    acc := Str:Obj[:] { it.ordered = true }
    addId(acc)
    addSpec(acc, spec)
    addDis(acc, spec)
    addSlots(acc, spec)
    addParentRefs(acc)
    dict := Etc.dictFromMap(acc)

    // decode to Fantom type
    if (spec.binding.isDict) dict = spec.binding.decodeDict(dict)

    // graph vs dict
    if (isGraph)
      return graph(spec, dict)
    else
      return dict
  }

  ** Input argument checks
  private Void checks(XetoSpec spec)
  {
    meta := spec.m.meta
    if (meta.has("abstract") && opts.missing("abstract")) throw Err("Spec is abstract: $spec.qname")
  }

//////////////////////////////////////////////////////////////////////////
// Non-Dicts
//////////////////////////////////////////////////////////////////////////

   ** Instantiate a list
  private List list(XetoSpec spec, Dict opts)
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

  ** Instantiate a scalar
  private Obj scalar(XetoSpec spec, Dict opts)
  {
    x := spec.meta["val"] ?: spec.type.meta["val"]
    if (x == null) x = ""
    return fidelity.coerce(x)
  }

//////////////////////////////////////////////////////////////////////////
// Dicts
//////////////////////////////////////////////////////////////////////////

  ** Add id if specified in opts or we are generating graph
  private Void addId(Str:Obj acc)
  {
    id := opts["id"]
    if (id == null && isGraph) id = Ref.gen
    if (id != null) acc["id"] = id
  }

  ** Always add the spec tag
  private Void addSpec(Str:Obj acc, Spec spec)
  {
    acc["spec"] = spec.type._id
  }

  ** Try to add reasonable default display tag
  private Void addDis(Str:Obj acc, Spec spec)
  {
    // add dis if not a dict slot
    isSlot := spec.parent != null && !spec.parent.isQuery
    if (!isSlot) acc["dis"] = XetoUtil.isAutoName(spec.name) ? spec.base.name : spec.name
  }

  ** Add slots
  private Void addSlots(Str:Obj acc, Spec spec)
  {
    spec.slots.each |s|
    {
      if (skipSlot(s)) return
      if (s.name == "enum") return acc.setNotNull("enum", enumDefault(s))
      acc.setNotNull(s.name, instantiate(s))
    }
  }

  ** Determine if we should skip a spec slot for instantiation purposes
  private Bool skipSlot(Spec slot)
  {
    if (slot.isQuery)  return true
    if (slot.isFunc)   return true
    if (slot.isChoice) return true // TODO: not sure about this one...
    if (slot.isMaybe)
    {
      // the rule for maybe types is that slot definition
      // itself must define a default value
      ownMeta := slot.metaOwn
      if (slot.metaOwn.has("val"))
        return false
      else
        return true
    }
    if (slot.isRef)
    {
      // don't default non-null ref slots to Ref default value "x"
      val := slot.get("val") as Ref
      if (val?.id == "x") return true
    }
    return false
  }

  ** Generate an enum default for the "enum" tag itself
  private Obj? enumDefault(XetoSpec slot)
  {
    val := slot.get("val")
    if (val == null) return null
    if (val is Ref) return val
    s := val.toStr
    if (!s.isEmpty) return s
    return null
  }

  ** Try to add in parent refs
  private Void addParentRefs(Str:Obj acc)
  {
    parentId := parent?.get("id") as Ref
    if (parentId == null) return

    // TODO: temp hack for equip/point common use case
    if (parent.has("equip"))   acc["equipRef"] = parentId
    if (parent.has("site"))    acc["siteRef"]  = parentId
    if (parent.has("siteRef")) acc["siteRef"]  = parent["siteRef"]
  }

//////////////////////////////////////////////////////////////////////////
// Graph
//////////////////////////////////////////////////////////////////////////

  ** Instantiate a graph with queries
  Dict[] graph(XetoSpec spec, Dict dict)
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
  const Bool isGraph
  Dict? parent
}

