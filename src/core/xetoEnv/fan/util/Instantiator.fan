//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 2025  Brian Frank  Pull out from XetoUtil
//

using util
using xeto
using haystack::Dict
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
** Options expanded from LibNamespace.instantiate for private use:
**   - 'graph': Marker tag to instantiate graph of recs (will auto-generate ids)
**   - 'abstract': marker to supress error if spec is abstract
**   - 'id': Ref tag to include in new instance
**   - 'haystack': marker tag to use Haystack level data fidelity
** Extended:
**   - 'graphInclude': map of Str:Str of qnames to explicitly include in graph
**   - 'conn': connector to bind, must be dict of '{id:@x, addrSpec:@FooAddr}'
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
    this.graphInclude = opts["graphInclude"] as Str:Str
    this.addTestTag = opts["addTestTag"] as Str
    initConnOpts
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

    // create dict
    dict := dict(spec)

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

  ** Instantiate a dict
  private Dict dict(XetoSpec spec)
  {
    // build up dict tags
    acc := Str:Obj[:] { it.ordered = true }
    addId(acc)
    addSpec(acc, spec)
    addDis(acc, spec)
    addSlots(acc, spec)
    addParentRefs(acc)
    if (addTestTag != null) acc[addTestTag] = Marker.val
    dict := Etc.dictFromMap(acc)

    // decode to Fantom type
    if (fidelity.isFull && spec.binding.isDict)
      dict = spec.binding.decodeDict(dict)

    return dict
  }

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
    // don't add display if a slot dict value
    isSlot := spec.parent != null && !spec.parent.isQuery
    if (isSlot) return

    // generate default display name
    dis := XetoUtil.isAutoName(spec.name) ? spec.base.name : spec.name

    // if spec has siteRef, then assume we are doing navName
    if (spec.slot("siteRef", false) != null)
    {
      parentRef   := isPoint(spec) ? "equipRef" : "siteRef"
      acc["navName"]  = dis
      acc["disMacro"] = "\$$parentRef \$navName"
    }
    else
    {
      acc["dis"] = dis
    }

    // update id with display name
    id := acc["id"] as Ref
    if (id != null) id.disVal = dis
  }

  ** Add slots
  private Void addSlots(Str:Obj acc, Spec spec)
  {
    spec.slots.each |s|
    {
      if (skipSlot(spec, s)) return
      if (s.name == "enum") return acc.setNotNull("enum", enumDefault(s))
      acc.setNotNull(s.name, instantiate(s))
    }
  }

  ** Determine if we should skip a spec slot for instantiation purposes
  private Bool skipSlot(Spec parent, Spec slot)
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

    // ref
    if (slot.isRef)
    {
      // don't default non-null ref slots to Ref default value "x"
      val := slot.get("val") as Ref
      if (val?.id == "x") return true
    }

    // skip FooAddr slots in a point (handled via conn)
    if (isPoint(parent) && isAddr(slot.type)) return true

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
    checkParentRef(acc, parentId, "site")
    checkParentRef(acc, parentId, "system")
    checkParentRef(acc, parentId, "space")
    checkParentRef(acc, parentId, "equip")
  }

  private Void checkParentRef(Str:Obj acc, Ref parentId, Str tag)
  {
    refTag := tag + "Ref"
    if (parent.has(tag))
    {
      // site -> siteRef=parentId
      acc[refTag] = parentId
    }
    else if (parent.has(refTag))
    {
      // siteRef -> siteRef=parent.siteRef
      acc[refTag] = parent.get(refTag)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Graph
//////////////////////////////////////////////////////////////////////////

  ** Instantiate a graph with queries
  Dict[] graph(XetoSpec spec, Dict root)
  {
    if (!isGraph) throw Err("must set graph opt")

    // push parent onto stack
    oldParent := this.parent
    this.parent  = root

    // recursively add constrained query children
    acc := Dict[,]
    acc.add(root)
    spec.slots.each |slot|
    {
      if (!slot.isQuery) return
      if (slot.slots.isEmpty) return
      addGraphQuery(acc, slot)
    }

    // restore parent from stack
    this.parent = oldParent

    return acc
  }

  ** Instantiate graph entities within given query
  private Void addGraphQuery(Dict[] acc, Spec query)
  {
    // TODO: need to treat attrs specially
    if (query.name == "attrs") return

    query.slots.each |x|
    {
      addGraphQuerySlot(acc, x)
    }
  }

  ** Instantiate one or zeor graph entity for given query slot
  private Void addGraphQuerySlot(Dict[] acc, Spec x)
  {
    // chck if we should skip it
    if (skipQuerySlot(x)) return null

    // instantiate as entities - graph mode will return Dict[]
    kids := instantiate(x) as List
    if (kids == null) return null

    // post-process first child only (only first maps to slot spec)
    kids.each |kid, i|
    {
      if (i == 0) kid = postProcessGraphQuerySlot(x, kid)
      acc.add(kid)
    }
  }

  ** Should we skip given query slot
  private Bool skipQuerySlot(Spec x)
  {
    if (graphInclude != null && !graphInclude.containsKey(x.qname)) return true
    return false
  }

  ** Post processing for query
  private Dict postProcessGraphQuerySlot(Spec recSlot, Dict rec)
  {
    // add connector info
    if (connId != null && isPoint(recSlot))
      rec = addConnAddr(recSlot, rec)

    return rec
  }

//////////////////////////////////////////////////////////////////////////
// Connector
//////////////////////////////////////////////////////////////////////////

  ** Init options: conn:{id, addrSpec}
  private Void initConnOpts()
  {
    c := opts["conn"] as Dict
    if (c == null) return

    // resolve required id tag
    this.connId = c.get("id") ?: throw Err("opts conn missing id")

    // resolve required addrSpec tag
    addrSpecId := c.get("addrSpec") as Ref ?: throw Err("opts conn missing addrSpec")
    this.connAddrSpec = ns.spec(addrSpecId.toStr)
  }

  ** Add connector tags
  private Dict addConnAddr(Spec ptSlot, Dict rec)
  {
    // find addr slot prototype
    Spec? addrSlot := null
    ptSlot.slots.each |x| { if (x.isa(connAddrSpec)) addrSlot = x }
    if (addrSlot == null) return rec

    // instantiate it
    addr := dict(addrSlot)
    addrVal := addr["addr"]
    if (addrVal == null) return rec

    // map to protocol specific tags
    name := connAddrSpec.name[0..-5].decapitalize
    markerTag  := name + "Point"
    connRefTag := name + "ConnRef"
    curTag     := name + "Cur"

    acc := Etc.dictToMap(rec)
    acc[markerTag]  = Marker.val
    acc[connRefTag] = connId
    acc[curTag]     = addrVal

    // TODO: special handling for bacnet, modbus, etc

    return Etc.dictFromMap(acc)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Is given spec a subtype of ph::Point
  Bool isPoint(Spec spec) { pointSpec !=null && spec.isa(pointSpec) }

  ** Is given spec a subtype of ph.protocols::ProtocolAddr
  Bool isAddr(Spec spec) { addrSpec !=null && spec.isa(addrSpec) }

  ** Spec for ph::Point
  once Spec? pointSpec() { ns.spec("ph::Point", false) }

  ** Spec for ph.protocols::ProtocolAddr
  once Spec? addrSpec() { ns.spec("ph.protocols::ProtocolAddr", false) }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns
  const Dict opts
  const XetoFidelity fidelity
  const Bool isGraph
  const Str? addTestTag
  private Dict? parent
  private [Str:Str]? graphInclude
  private Ref? connId
  private Spec? connAddrSpec
}

