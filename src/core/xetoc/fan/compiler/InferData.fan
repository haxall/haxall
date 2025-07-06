//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jul 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Walk thru all the dict AST spec meta and instances and add inferred types/tags.
** Once complete every AData instance must have its typeRef set.
**
** We run this in two passes: first to infer lib/spec meta; then for instances.
**
**
internal abstract class InferData : Step
{
  Void infer(ANode node)
  {
    if (node.nodeType === ANodeType.spec)     curSpec = node
    if (node.nodeType === ANodeType.dict)     inferDict(node)
    if (node.nodeType === ANodeType.instance) inferInstance(node)
    if (node.nodeType === ANodeType.scalar)   inferScalar(node)
    if (node.nodeType === ANodeType.specRef)  inferRef(node)
    if (node.nodeType === ANodeType.dataRef)  inferRef(node)
  }

  private Void inferInstance(AInstance dict)
  {
    curSpec = null
    inferId(dict)
    inferDict(dict)
  }

  private Void inferDict(ADict dict)
  {
    if (dict.isMeta)
      inferMetaSlots(dict)
    else
      inferDictSlots(dict)
  }

  private Void inferScalar(AScalar scalar)
  {
    if (scalar.typeRef == null || isObj(scalar.ctype))
      scalar.typeRef = sys.str
  }

  private Void inferRef(ARef ref)
  {
    if (ref.typeRef == null)
      ref.typeRef = sys.ref
  }

  private Void inferId(AInstance dict)
  {
    // add "id" tag with Ref scalar value
    loc := dict.loc
    if (dict.has("id")) err("Named dict cannot have explicit id tag", loc)
    dict.set("id", AScalar(loc, sys.ref, dict.id.toStr, dict.id))
  }

  private Void inferMetaSlots(ADict dict)
  {
    dict.each |v, n|
    {
      inferMetaSlot(dict, n, v)
    }
  }

  private Void inferMetaSlot(ADict dict, Str name, AData val)
  {
    // resolve to meta spec
    metaSpec := cns.metaSpec(name, val.loc)

    // if not found then report error
    if (metaSpec == null)
    {
      // if this is reserved slot, then we will flag in CheckErrors
      if (dict.isSpecMeta && XetoUtil.isReservedSpecMetaName(name)) return
      if (dict.isLibMeta && XetoUtil.isReservedLibMetaName(name)) return

      // log error for meta tags not defined
      err("Undefined meta tag '$name'", val.loc)
      return
    }

    // if already typed, skip
    if (val.typeRef != null) return

    // if meta tag is self, then use parent spec type
    type := metaSpec.ctype
    if (type.isSelf)
    {
      parentSpec := dict.metaParent as ASpec
      if (parentSpec == null)
        err("Unexpected self meta '$name' outside of spec", dict.loc)
      else
        type = parentSpec.ctype
    }

    // type the meta tag using global type
    val.typeRef = inferDictSlotType(val.loc, metaSpec)
  }

  private Void inferDictSlots(ADict dict)
  {
    // untyped dicts default to sys::Dict
    if (dict.typeRef == null) dict.typeRef = sys.dict

    // walk thru the spec slots and infer type/value
    spec := dict.ctype

    // infer slots from specs
    spec.cslots |slot|
    {
      inferDictSlot(dict, slot)
    }

    // infer values from parameterized of
    of := dict.typeRef?.of
    if (of != null)
    {
      dict.each |item|
      {
        if (item.typeRef == null)
          item.typeRef = ASpecRef(item.loc, of)
      }
    }

    // infer any non-type dict name/value pairs from globals
    dict.map.each |v, n|
    {
      if (v.typeRef != null) return

      // if dict is xmeta then infer from meta, otherwise global
      CSpec? global
      if (dict.isXMeta)
        global = cns.metaSpec(n, v.loc)
      else
        global = cns.global(n, v.loc)
      if (global == null) return

      v.typeRef = inferDictSlotType(v.loc, global.ctype)
    }
 }

  private Void inferDictSlot(ADict dict, CSpec slot)
  {
    // get the slot value
    cur := dict.get(slot.name)

    // if no value and slot is nullable, then don't infer anything
    if (cur == null && slot.isMaybe) return

    // if we have a slot value, then infer the type only
    if (cur != null)
    {
      if (cur.typeRef == null)
        cur.typeRef = inferDictSlotType(cur.loc, slot)
      return
    }

    // if slot is defined in the lib itself
    CSpec cspec := slot
    if (slot.isAst)
    {
      val := ((ASpec)slot).metaGet("val") as AData
      if (val != null)
      {
        dict.set(slot.name, val)
        return
      }
      cspec = slot.ctype
    }

    val := cspec.cmeta.get("val")
    if (val == null) return
    if (val == refDefVal) return
    type := inferDictSlotType(dict.loc, slot)
    dict.set(slot.name, AScalar(dict.loc, type, val.toStr, val))
  }

  private ASpecRef inferDictSlotType(FileLoc loc, CSpec slot)
  {
    type := slot.ctype
    if (type.isSelf && curSpec != null) type = curSpec.ctype
    ref := ASpecRef(loc, type)
    ref.of = slot.cof // smuggle parameterized 'of' into ASpecRef
    return ref
  }

  const Ref refDefVal := Ref("x")

  private ASpec? curSpec
}

**************************************************************************
** InferMeta
**************************************************************************

internal class InferMeta : InferData
{
  override Void run()
  {
    ast.walkMetaTopDown |node| { infer(node) }
  }
}

**************************************************************************
** InferInstances
**************************************************************************

internal class InferInstances : InferData
{
  override Void run()
  {
    ast.walkInstancesTopDown |node| { infer(node) }
  }
}

