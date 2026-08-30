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
    inferDictSlots(dict)
    if (isGridDict(dict)) inferGrid(dict)
  }

  private Void inferScalar(AScalar scalar)
  {
    if (scalar.typeRef == null || isObj(scalar.type))
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

  private Void inferDictSlots(ADict dict)
  {
    // untyped dicts default to sys::Dict
    if (dict.typeRef == null) dict.typeRef = sys.dict

    // infer slots and globals from spec
    members := dict.isSpecMeta ? this.metas : dict.type.members
    members.each |slot|
    {
      inferDictSlot(dict, slot)
    }

    // infer values from parameterized of
    of := dictOf(dict)
    if (of != null)
    {
      dict.each |item|
      {
        if (item.typeRef == null)
          item.typeRef = ASpecRef(item.loc, of)
      }
    }
  }

  ** Component spec used to type a dict's unnamed items.  Prefer the
  ** declaring slot's parameterized 'of' smuggled into the ASpecRef; a
  ** top-level instance has no such slot, so fall back to the type's own
  ** 'of' meta which is how 'Foos: Dict <of:Foo>' types its items.  Walk
  ** the bases since an AST spec has not inherited its meta yet.
  private Spec? dictOf(ADict dict)
  {
    ref := dict.typeRef
    if (ref.of != null) return ref.of
    for (Spec? s := ref.isResolved ? ref.deref : null; s != null; s = s.base)
    {
      of := s.of(false)
      if (of != null) return of
    }
    return null
  }

  private Void inferDictSlot(ADict dict, Spec slot)
  {
    // get the slot value
    cur := dict.get(slot.name)

    // if no value and slot is nullable/global, then don't infer anything
    if (cur == null)
    {
      if (dict.isMeta || slot.isGlobal || slot.isMaybe) return
    }

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
    if (type.isThis && curSpec != null) type = curSpec.type
    ref := ASpecRef(loc, type)
    ref.of = slot.of(false) // smuggle parameterized 'of' into ASpecRef
    return ref
  }

//////////////////////////////////////////////////////////////////////////
// Grids
//////////////////////////////////////////////////////////////////////////

  ** Type the cells of a grid shaped dict - see doc.xeto::Grids.  The
  ** walk is top down, so the cells are typed here before their own
  ** visit and Reify just decodes.  Precedence: a cell or row with its
  ** own type keeps it, then the column 'of', then the row spec member,
  ** where the row spec is the row's own type else the grid 'of'.
  private Void inferGrid(ADict dict)
  {
    // column 'of' specs by name
    colOf := Str:Spec[:]
    cols := dict.get("cols") as ADict
    cols?.each |c|
    {
      cd := c as ADict
      name := cd?.getStr("name")
      of := (cd?.get("of") as ASpecRef)?.deref
      if (name != null && of != null) colOf[name] = of
    }

    // default row spec is the instance 'of'
    rowSpec := (dict.get("of") as ASpecRef)?.deref

    rows := dict.get("rows") as ADict
    rows?.each |r|
    {
      rd := r as ADict
      if (rd == null) return

      // a row with its own type infers its members from that type in
      // inferDictSlots instead of the grid 'of'
      member := rd.typeRef == null ? rowSpec : null
      rd.each |cell, name|
      {
        if (cell.typeRef != null) return
        cof := colOf[name]
        if (cof != null) { cell.typeRef = ASpecRef.makeResolved(cell.loc, cof); return }
        slot := member?.member(name, false)
        if (slot != null) cell.typeRef = inferDictSlotType(cell.loc, slot)
      }
    }
  }

  ** Is dict's resolved type a grid
  private static Bool isGridDict(ADict dict)
  {
    typeRef := dict.typeRef
    if (typeRef == null || !typeRef.isResolved) return false
    type := typeRef.deref
    return !type.isAst && type.isGrid
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

