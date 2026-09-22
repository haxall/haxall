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
** InheritEnum does the specialized InheritSlots just for enum types.
**
@Js
internal class InheritEnums : InheritFlags
{
  override Void run()
  {
    lib.tops.each |spec|
    {
      if (spec.isEnum) inherit(spec)
    }
    bombIfErr
  }

  ** Enum slots are implied as the parent type
  private Void inherit(ASpec spec)
  {
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
    spec.setMembers(SpecMap(slots))
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

}

