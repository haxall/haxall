//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Sep 2026  Brian Frank  Split from InheritSpecs
//

using util
using xeto
using xetom
using haystack

**
** InheritBase walks all top specs to resolve the following ASpec fields:
**   - base
**   - typeRef
**   - flags
**
** We also use this step to create a list of types orderd by inheritance
** for subsequent steps to use in lib.types.
**
@Js
internal class InheritBase : InheritFlags
{
  override Void run()
  {
    lib.tops.each |spec| { inherit(spec) }
    bombIfErr
    lib.ast.topsInInheritOrder = mixins.addAll(types)
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  ** Process inheritance of given spec with cyclic checks
  private Void inherit(ASpec spec)
  {
    // check if already processed
    if (spec.ast.flags >= 0) return

    // check for cyclic inheritance
    if (isCyclicInheritance(spec) && !isSys)
    {
      // report error for every type in the cycle
      types := Str:Str[:]
      stack.each |s| { if (s.isType) types[s.qname] = s.qname }
      err("Cyclic inheritance: " + types.vals.sort.join(", "), spec.loc)
      spec.flags = 0
      spec.setNoMembers
      return
    }

    // push onto stack to keep track of cycles
    stack.push(spec)

    // process
    doInherit(spec)

    // pop from stack
    stack.pop
  }

  private Bool isCyclicInheritance(ASpec spec)
  {
    // walk stack backwards checking if spec is already on the stack
    // via a pure type inheritance path (not thru slot references)
    for (i := stack.size - 1; i >= 0; --i)
    {
      s := stack[i]
      if (s === spec) return true

      /*
      // if we turn this on we can have slots that forward refernce
      // subtypes of the parent type; however enabling that will
      // break RemoteLoader which requires a single pass; see the
      // hx.test.xeto test for "TestWidget" and "TestTool"
      if (!s.isType) return false
      */
    }
    return false
  }

  private Void doInherit(ASpec spec)
  {
    // special handling for sys::Obj
    if (spec.isObj)
    {
      spec.flags = 0
      spec.setNoMembers
      types.add(spec)
      return
    }

    // infer the base we inherit from (may be null)
    spec.ast.base = inferBase(spec)

    // now infer the type of the spec
    explicitTypeRef := spec.typeRef != null
    if (!explicitTypeRef) spec.typeRef = inferType(spec)

    // if we couldn't infer base before, then use type as base
    if (spec.base == null) spec.ast.base = spec.typeRef.deref

    // if base is in my AST, then recursively process it first
    if (spec.base.isAst) inherit(spec.base)

    // keep track of tops in order now that inheritance has been processed
    if (spec.isType) types.add(spec)
    if (spec.isMixin) mixins.add(spec)

    // if base is maybe and my own type is not then clear maybe flag
    if (explicitTypeRef && spec.base.isMaybe && !spec.metaHas("maybe"))
      spec.metaSetNone("maybe")

    // special handling for Enums
    if (isEnum(spec)) return inheritEnum(spec)

    // compute effective flags
    inheritFlags(spec)
  }

//////////////////////////////////////////////////////////////////////////
// Infer Base
//////////////////////////////////////////////////////////////////////////

  ** Infer the base spec we inherit from
  Spec? inferBase(ASpec x)
  {
    // if already inferred
    if (x.base != null) return x.base

    // try to infer from the explicit type if available
    return x.typeRef?.deref
  }

//////////////////////////////////////////////////////////////////////////
// Infer Type
//////////////////////////////////////////////////////////////////////////

  ** If x does not have an explicit type specified, then infer
  ** it from either given base or whether it is a scalar/dict.
  ** If a type is given, then we use that to decide if we need
  ** clear maybe flag (set to None).
  ASpecRef inferType(ASpec x)
  {
    // if already specified use it
    if (x.typeRef != null) return x.typeRef

    // infer type from base
    if (x.base != null) return ASpecRef(x.loc, x.base.type)

    // items of a MultiRef list are always refs
    if (x.parent != null && x.parent.isMultiRef) return x.typeRef = sys.ref

    // scalars default to str and everything else to dict
    x.typeRef = x.val == null ? sys.dict : sys.str
    return x.typeRef
  }

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  ** At this point the ASpec.type will be sys::Enum (base is still null)
  private Bool isEnum(ASpec spec)
  {
    t := spec.typeRef.deref
    return t.isSys && t.name == "Enum" && spec.isType
  }

  ** Enum slots are implied as the parent type
  private Void inheritEnum(ASpec spec)
  {
    // set base to typeRef (which is sys::Enum)
    spec.ast.base = spec.typeRef.deref

    // set flags
    spec.flags = spec.base.flags.or(MSpecFlags.enum)

    // sealed is implied
    loc := spec.loc
    if (spec.metaHas("sealed"))
      err("Enum types are implied sealed", loc)
    else
      spec.metaInit.set("sealed", sys.markerScalar(loc))

    // recurse children slots to process as the enum items
    slots := Str:Spec[:]; slots.ordered = true
    enums := Str:Spec[:]; enums.ordered = true
    hasKeys := false
    enumRef := ASpecRef(loc, spec)
    defKey := null
    spec.declared?.each |slot|
    {
      item := inheritEnumItem(spec, enumRef, slot)

      // map slot by its programatic name
      slots.add(item.name, item)

      // map by key
      key := item.name
      keyVal := item.metaGet("key") as AScalar
      if (keyVal != null)
      {
        key = keyVal.str
        hasKeys = true
      }
      if (enums[key] != null)
        err("Duplicate enum key: $key", item.loc)
      else
        enums.add(key, item)

      if (defKey == null) defKey = key
    }

    // if we don't have any key meta, then reuse same slots map to save RAM
    if (!hasKeys) enums = slots

    // set first key to the default value for enum type
    if (defKey == null)
      err("Enum has no items", spec.loc)
    else
      spec.metaInit.set("val", AScalar(spec.loc, enumRef, defKey))

    // save away both slots and enums
    specMap := SpecMap(slots)
    spec.ast.members = specMap
    spec.ast.slots   = specMap
    spec.ast.enum    = MEnum(enums, defKey ?: "")
  }

  ** Check that an item was a marker only, then coerce to be derived from parent enum
  private ASpec inheritEnumItem(ASpec enum, ASpecRef enumRef, ASpec item)
  {
    // this should only be true if slot created in Parser.parseMarkerSpec
    if (item.typeRef !== sys.marker)
      err("Enum item '$item.name' cannot have type", item.loc)

    item.ast.base = enum
    item.typeRef  = enumRef
    item.flags    = enum.flags
    item.setNoMembers
    return item
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private ASpec[] stack  := [,]
  private ASpec[] types  := [,]
  private ASpec[] mixins := [,]
}

