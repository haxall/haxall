//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Aug 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** CheckErrors is run late in the pipeline to perform AST validation
**
internal class CheckErrors : Step
{
  override Void run()
  {
    if (isLib)
      checkLib(lib)
    else
      checkData(data.root)
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  Void checkLib(ALib x)
  {
    checkLibMeta(lib)
    x.tops.each |type| { checkTop(type) }
    x.instances.each |instance| { checkDict(instance) }
  }

  Void checkLibMeta(ALib x)
  {
    libMetaReservedTags.each |name|
    {
      if (x.meta.has(name)) err("Lib '$x.name' cannot use reserved meta tag '$name'", x.loc)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  Void checkTop(ASpec x)
  {
    checkSpec(x)
    checkTypeInherit(x)
  }

  Void checkTypeInherit(ASpec x)
  {
    if (!x.isType) return
    if (x.base == null) return // Obj
    base := x.cbase

    // enums are effectively sealed even in same lib
    if (base.isEnum)
      return err("Cannot inherit from Enum type '$base.name'", x.loc)

    // cannot subtype from sealed types in external libs
    // Note: we allow this in cases like <of:Ref<of:Site>>
    if (base.cmeta.has("sealed") && !base.isAst && !x.parsedSyntheticRef)
      return err("Cannot inherit from sealed type '$base.name'", x.loc)

    // cannot subtype from And/Or without using & or |
    if (!isSys && (base === env.sys.and || base === env.sys.or) && !x.parsedCompound)
      return err("Cannot directly inherit from compound type '$base.name'", x.loc)
  }

  Void checkSpec(ASpec x)
  {
    checkMeta(x)
    if (x.isQuery)
      checkQuery(x)
    else
      checkSlots(x)
  }

  Void checkSlots(ASpec x)
  {
    if (x.slots == null) return
    x.slots.each |slot| { checkSlot(slot) }
  }

  Void checkSlot(ASpec x)
  {
    checkSpec(x)
    checkSlotType(x)
    checkSlotVal(x)
  }

  Void checkSlotType(ASpec slot)
  {
    // don't run these checks for enum items
    if (slot.parent.isEnum) return

    // get base type (inherited or global slot)
    base := slot.base
    baseType := base.ctype
    if (baseType == null) return // if base is sys::Obj

    // verify slot type is covariant
    slotType := slot.ctype
    if (!slotType.cisa(baseType))
    {
      if (slot.base.isGlobal)
        err("Slot '$slot.name' type '$slotType' conflicts global slot '$base.qname' of type '$baseType'", slot.loc)
      else
        err("Slot '$slot.name' type '$slotType' conflicts inherited slot '$base.qname' of type '$baseType'", slot.loc)
    }

  }

  Void checkSlotVal(ASpec slot)
  {
    // scalars cannot have slots
    if (slot.ctype.isScalar)
    {
      if (slot.slots != null) err("Scalar slot '$slot.name' of type '$slot.ctype' cannot have slots", slot.loc)
    }

    // non-scalars cannot have value
    else
    {
      if (slot.val != null) err("Non-scalar slot '$slot.name' of type '$slot.ctype' cannot have scalar value", slot.loc)
    }
  }

  Void checkMeta(ASpec x)
  {
    if (x.meta == null) return

    specMetaReservedTags.each |name|
    {
      if (x.meta.has(name)) err("Spec '$x.name' cannot use reserved meta tag '$name'", x.loc)
    }

    checkDict(x.meta)
  }

  Void checkQuery(ASpec x)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////////

  Void checkData(AData x)
  {
    switch (x.nodeType)
    {
      case ANodeType.dict: checkDict(x)
      case ANodeType.scalar: checkScalar(x)
      case ANodeType.specRef: checkSpecRef(x)
      case ANodeType.dataRef: checkDataRef(x)
    }
  }

  Void checkDict(ADict x)
  {
  }

  Void checkScalar(AScalar x)
  {
  }

  Void checkSpecRef(ASpecRef x)
  {
  }

  Void checkDataRef(ADataRef x)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const Str[] libMetaReservedTags := [
    // used right now
    "id", "spec", "loaded",
    // future proofing
    "data", "instances", "name", "lib", "loc", "slots", "specs", "types", "xeto"
  ]

  const Str[] specMetaReservedTags := [
    // used right now
    "id", "base", "type", "spec", "slots",
    // future proofing
    "class", "is", "lib", "loc", "name", "parent", "qname", "super", "supers", "version", "xeto"
  ]

}