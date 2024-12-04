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
    // make id qualified if this is lib data
    id := dict.name.toStr
    if (isLib) id = lib.name + "::" + id

    // add "id" tag with Ref scalar value
    loc := dict.loc
    ref := compiler.makeRef(id, null)
    if (dict.has("id")) err("Named dict cannot have explicit id tag", loc)
    dict.set("id", AScalar(loc, sys.ref, id, ref))
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
    // resolve to global meta
    global := cns.globalMeta(name)

    // if not found then report error
    if (global == null)
    {
      // in my implementation these are ok and not formally defined
      if (name == "fantomPodName") return

      // log error for meta tags not defined
//echo("WARN: Meta data tag '$name' is not formally defined [$val.loc]")
      return
    }

    // if already typed, skip
    if (val.typeRef != null) return

    // if meta tag is self, then use parent spec type
    type := global.ctype
    if (type.isSelf)
    {
      if (dict.metaParent == null)
        err("Unexpected self meta '$name' outside of spec", dict.loc)
      else
        type = dict.metaParent.ctype
    }

    // type the meta tag using global type
    val.typeRef = ASpecRef(val.loc, type)
  }

  private Void inferDictSlots(ADict dict)
  {
    // untyped dicts default to sys::Dict
    if (dict.typeRef == null) dict.typeRef = sys.dict

    // walk thru the spec slots and infer type/value
    spec := dict.ctype

    // infer slots
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

    // we don't infer meta dict slots, that is handled in InheritMeta
    if (dict.isMeta) return

    // we don't infer slots from interfaces
    if (slot.cparent.isInterface) return

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

  const Ref refDefVal := haystack::Ref("x")

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

