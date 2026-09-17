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
internal class InheritBase : Step
{
  override Void run()
  {
    lib.tops.each |spec| { inherit(spec) }
    bombIfErr
    lib.ast.topsInInheritOrder = tops
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  ** Process inheritance of given spec with cyclic checks
  private Void inherit(ASpec spec)
  {
    // check if already inherited
    if (spec.ast.members != null) return

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
      tops.add(spec)
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

    // keep track of type now that inheritance has been processed
    if (spec.isTop) tops.add(spec)

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
// Flags
//////////////////////////////////////////////////////////////////////////

  ** Compute the effective flags which is bitmask used for
  ** fast access of key types in my inheritance hiearchy
  private Void inheritFlags(ASpec x)
  {
    if (isSys)
      x.flags = computeFlagsSys(x)
    else if (isSysComp)
      x.flags = computeFlagsSysComp(x)
    else
      x.flags = computeFlagsNonSys(x)
  }

  private Int computeFlagsNonSys(ASpec x)
  {
    // start off with my base type flags that are inherited
    flags := x.base.flags.and(MSpecFlags.inheritMask)

    // global is both flavor and flag so we can use one MSpec
    if (x.isGlobal) flags = flags.or(MSpecFlags.global)

    // merge in my own meta flags
    if (x.ast.meta != null)
    {
      flags = setMetaFlag(flags, x, "maybe",     MSpecFlags.maybe)
      flags = setMetaFlag(flags, x, "transient", MSpecFlags.transient)
      flags = setMetaFlag(flags, x, "output",    MSpecFlags.output)
    }

    // if my base is compound type
    baseName := x.base.name
    switch (baseName)
    {
      case "And":  flags = flags.or(MSpecFlags.and)
      case "Or":   flags = flags.or(MSpecFlags.or)
    }

    // special handling ph lib
    if (isPh)
    {
      switch (x.name)
      {
        case "Coord":  flags = flags.or(MSpecFlags.haystack)
        case "Symbol": flags = flags.or(MSpecFlags.haystack)
      }
    }

    return flags
  }

  ** If given meta tag defined then set bit flag (or clear if None)
  private Int setMetaFlag(Int flags, ASpec x, Str name, Int bit)
  {
    val := x.ast.meta.get(name)
    if (val == null) return flags
    if (val.isNone)  return flags.and(bit.not)
    return flags.or(bit)
  }

  ** Treat `sys` itself special using names
  private Int computeFlagsSys(ASpec x)
  {
    // maybe
    flags := 0
    if (x.metaHas("maybe")) flags = flags.or(MSpecFlags.maybe)

    // inherited flags
    for (ASpec? p := x; p != null; p = p.base)
    {
      switch (p.name)
      {
        case "Choice":    flags = flags.or(MSpecFlags.choice)
        case "Dict":      flags = flags.or(MSpecFlags.dict)
        case "Entity":    flags = flags.or(MSpecFlags.entity)
        case "File":      flags = flags.or(MSpecFlags.file)
        case "Func":      flags = flags.or(MSpecFlags.func)
        case "Grid":      flags = flags.or(MSpecFlags.grid)
        case "Interface": flags = flags.or(MSpecFlags.interface)
        case "List":      flags = flags.or(MSpecFlags.list)
        case "Marker":    flags = flags.or(MSpecFlags.marker)
        case "MultiRef":  flags = flags.or(MSpecFlags.multiRef)
        case "NA":        flags = flags.or(MSpecFlags.haystack)
        case "None":      flags = flags.or(MSpecFlags.none).or(MSpecFlags.haystack)
        case "Query":     flags = flags.or(MSpecFlags.query)
        case "Ref":       flags = flags.or(MSpecFlags.ref)
        case "Scalar":    flags = flags.or(MSpecFlags.scalar)
        case "This":      flags = flags.or(MSpecFlags.self)
      }
    }

    // haystack Kind specs (non-inherited)
    if (x.isType)
    {
      typeName := x.name
      kind := Kind.fromStr(typeName, false)
      if (kind != null && (typeName != "Obj" && typeName != "Span"))
        flags = flags.or(MSpecFlags.haystack)
    }

    return flags
  }

  ** Handle flags in `sys.comp`
  private Int computeFlagsSysComp(ASpec x)
  {
    if (x.name == "Comp") return MSpecFlags.comp
    return computeFlagsNonSys(x)
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

  private ASpec[] stack := [,]
  private ASpec[] tops := [,]
}

