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
**
internal class InferData : Step
{
  override Void run()
  {
    ast.walkTopDown |node|
    {
      if (node.nodeType === ANodeType.spec)     curSpec = node
      if (node.nodeType === ANodeType.dict)     inferDict(node)
      if (node.nodeType === ANodeType.instance) inferInstance(node)
      if (node.nodeType === ANodeType.scalar)   inferScalar(node)
      if (node.nodeType === ANodeType.specRef)  inferRef(node)
      if (node.nodeType === ANodeType.dataRef)  inferRef(node)
    }
  }

  private Void inferInstance(AInstance dict)
  {
    curSpec = null
    inferId(dict)
    inferDict(dict)
  }

  private Void inferDict(ADict dict)
  {
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

  private Void inferDictSlots(ADict dict)
  {
    // untyped dicts default to sys::Dict
    if (dict.typeRef == null) dict.typeRef = sys.dict

    // walk thru the spec slots and infer type/value
    spec := dict.ctype
    spec.cslots |slot|
    {
      inferDictSlot(dict, slot)
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
        cur.typeRef = ASpecRef(cur.loc, inferDictSlotType(slot))
      return
    }

    // we don't infer meta dict slots, that is handled in InheritMeta
    if (dict.isMeta) return

    // we haven't run InheritMeta yet, so this is awkward....
    // TODO: we need to run InheritMeta before Reify
    CSpec cspec := slot
    if (slot.isAst)
    {
      val := ((ASpec)slot).metaGet("val") as AScalar
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
    dict.set(slot.name, AScalar(dict.loc, null, val.toStr, val))
  }

  private CSpec inferDictSlotType(CSpec slot)
  {
    type := slot.ctype
    if (type.isSelf && curSpec != null) return curSpec.ctype
    return type
  }

  const Ref refDefVal := haystack::Ref("x")

  private ASpec? curSpec
}

