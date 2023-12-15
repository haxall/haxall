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
** Walk thru all the dict AST instances and add inferred types/tags
**
**
internal class InferData : Step
{
  override Void run()
  {
    ast.walkTopDown |node|
    {
      if (node.nodeType === ANodeType.dict) inferDict(node)
      if (node.nodeType === ANodeType.instance) inferInstance(node)
    }
  }

  private Void inferInstance(AInstance dict)
  {
    inferId(dict)
    inferDict(dict)
  }

  private Void inferDict(ADict dict)
  {
    inferDictSlots(dict)
  }

  private Void inferId(AInstance dict)
  {
    // make id qualified if this is lib data
    id := dict.name.toStr
    if (isLib) id = lib.name + "::" + id

    // add "id" tag with Ref scalar value
    loc := dict.loc
    ref := env.ref(id, null)
    if (dict.has("id")) err("Named dict cannot have explicit id tag", loc)
    dict.set("id", AScalar(loc, sys.ref, id, ref))
  }

  private Void inferDictSlots(ADict dict)
  {
    // walk thru the spec slots and infer type/value
    if (dict.typeRef == null) return //echo("WARN: Dict not typed [$dict.loc]")

    spec := dict.ctype
    spec.cslots |slot|
    {
      inferDictSlot(dict, slot)
    }

    // walk thru any remaining slots and infer type
    dict.each |val|
    {
      if (val.typeRef == null) inferValType(val)
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
        cur.typeRef = ASpecRef(cur.loc, slot.ctype)
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

  private Void inferValType(AData data)
  {
    switch (data.nodeType)
    {
      case ANodeType.scalar:   data.typeRef = sys.str
      case ANodeType.dict:     data.typeRef = sys.dict
      case ANodeType.instance: data.typeRef = sys.dict
      case ANodeType.dataRef:  data.typeRef = sys.ref
      case ANodeType.specRef:  data.typeRef = sys.ref
      default: throw err("inferValType $data $data.nodeType", data.loc)
    }
  }

  const Ref refDefVal := haystack::Ref("x")
}