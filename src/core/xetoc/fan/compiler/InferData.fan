//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jul 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Walk thru all the dict AST spec meta and instances and add inferred types/tags.
** Once complete every AData instance must have its typeRef set.
**
** We run this in two passes: first to infer lib/spec meta; then for instances.
**
@Js
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
// TODO
    metaSpec := cns.metaSpec(name, val.loc) as Spec

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
    type := metaSpec.type
    if (type.isSelf)
    {
      parentSpec := dict.metaParent as ASpec
      if (parentSpec == null)
        err("Unexpected self meta '$name' outside of spec", dict.loc)
      else
        type = parentSpec.type
    }

    // type the meta tag using global type
    val.typeRef = inferDictSlotType(val.loc, metaSpec)
  }

  private Void inferDictSlots(ADict dict)
  {
    // untyped dicts default to sys::Dict
    if (dict.typeRef == null) dict.typeRef = sys.dict

    // walk thru the spec slots and infer type/value
    spec := dict.type

    // infer slots and globals from spec
    spec.members.each |slot|
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
          item.typeRef = ASpecRef.makeTemp(item.loc, of)
      }
    }
  }

  private Void inferDictSlot(ADict dict, Spec slot)
  {
    // get the slot value
    cur := dict.get(slot.name)

    // if no value and slot is nullable/global, then don't infer anything
    if (cur == null && (slot.isGlobal || slot.isMaybe)) return

    // if we have a slot value, then infer the type only
    if (cur != null)
    {
      if (cur.typeRef == null)
        cur.typeRef = inferDictSlotType(cur.loc, slot)
      return
    }

    // if slot is defined in the lib itself
    spec := slot
    if (slot.isAst)
    {
      val := ((ASpec)slot).metaGet("val") as AData
      if (val != null)
      {
        dict.set(slot.name, val)
        return
      }
      spec = slot.type
    }

    val := spec.meta.get("val")
    if (val == null) return
    if (val == refDefVal) return
    type := inferDictSlotType(dict.loc, slot)
    dict.set(slot.name, AScalar(dict.loc, type, val.toStr, val))
  }

  private ASpecRef inferDictSlotType(FileLoc loc, Spec slot)
  {
    type := slot.type
    if (type.isSelf && curSpec != null) type = curSpec.type
    ref := ASpecRef.makeTemp(loc, type)
    ref.of = slot.of(false) // smuggle parameterized 'of' into ASpecRef
    return ref
  }

  const Ref refDefVal := Ref("x")

  private ASpec? curSpec
}

**************************************************************************
** InferMeta
**************************************************************************

@Js
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

@Js
internal class InferInstances : InferData
{
  override Void run()
  {
    ast.walkInstancesTopDown |node| { infer(node) }
  }
}

