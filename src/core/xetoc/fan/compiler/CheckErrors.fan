//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Aug 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::Number
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
      checkData(data.root, null)
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  Void checkLib(ALib x)
  {
    if (!XetoUtil.isLibName(x.name)) err("Invalid lib name '$x.name': " + XetoUtil.libNameErr(x.name), x.loc)
    checkLibMeta(lib)
    x.tops.each |type| { checkTop(type) }
    x.instances.each |instance, name| { checkInstance(x, name, instance) }
  }

  Void checkLibMeta(ALib x)
  {
    XetoUtil.libMetaReservedTags.each |name|
    {
      if (x.meta.has(name)) err("Lib '$x.name' cannot use reserved meta tag '$name'", x.loc)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  Void checkTop(ASpec x)
  {
    checkTopName(x)
    checkTypeInherit(x)
    checkSpec(x)
  }

  Void checkTopName(ASpec x)
  {
    if (lib.instances[x.name] != null)
      err("Spec '$x.name' conflicts with instance of the same name", x.loc)

    if (XetoUtil.isReservedSpecName(x.name))
      err("Spec name '$x.name' is reserved", x.loc)
  }

  Void checkTypeInherit(ASpec x)
  {
    if (!x.isType) return
    if (x.base == null) return // Obj
    base := x.cbase

    // check inheritance from base
    checkCanInheritFrom(x, base, x.loc)

    // cannot subtype from And/Or without using & or |
    if ((x.isAnd || x.isOr) && !x.parsedCompound)
      return err("Cannot directly inherit from compound type '$base.name'", x.loc)

    // check compount types
    if (x.parsedCompound)
      checkCompoundType(x)
  }

  Void checkCompoundType(ASpec x)
  {
    CSpec? dict := null
    CSpec? list := null
    CSpec? scalar := null

    x.cofs.each |of|
    {
      // keep track of flags
      if (of.isDict)   dict = of
      if (of.isList)   list = of
      if (of.isScalar) scalar = of

      // check standard inheritance rules
      checkCanInheritFrom(x, of, x.loc)
    }

    // check invalid AND combinations
    if (x.isAnd)
    {
      if (scalar != null && dict != null) err("Cannot And scalar '$scalar.name' and dict '$dict.name'", x.loc)
      if (scalar != null && list != null) err("Cannot And scalar '$scalar.name' and list '$list.name'", x.loc)
      if (dict != null && list != null)   err("Cannot And dict '$dict.name' and list '$list.name'", x.loc)
    }
  }

  Void checkCanInheritFrom(ASpec x, CSpec base, FileLoc loc)
  {
    // enums are effectively sealed even in same lib
    if (base.isEnum)
      return err("Cannot inherit from Enum type '$base.name'", loc)

    // cannot subtype from sealed types in external libs
    // Note: we allow this in cases like <of:Ref<of:Site>>
    if (base.cmeta.has("sealed") && !base.isAst && !x.parsedSyntheticRef)
      return err("Cannot inherit from sealed type '$base.name'", loc)
  }


  Void checkSpec(ASpec x)
  {
    checkSpecMeta(x)
    if (x.isQuery) return checkSpecQuery(x)
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

    // verify slot type is covariant
    slotType := slot.ctype
    if (!slotType.cisa(baseType))
    {
      if (slot.base.isGlobal)
        err("Slot '$slot.name' type '$slotType' conflicts global slot '$base.qname' of type '$baseType'", slot.loc)
      else
        err("Slot '$slot.name' type '$slotType' conflicts inherited slot '$base.qname' of type '$baseType'", slot.loc)
    }

    // lists cannot have slots
    if (slot.parent.isList)
      err("List specs cannot define slots", slot.loc)

    // choices can have only markers
    if (slot.parent.isChoice && !slot.ctype.isMarker)
      err("Choice slot '$slot.name' must be marker type", slot.loc)
  }

  Void checkSlotVal(ASpec slot)
  {
    // slots of type Obj can have either scalar or slots (but not both)
    if (isObj(slot.ctype))
    {
      // this actually should never happen because we don't parse this case
      if (slot.val != null && slot.slots != null)
        err("Cannot have both scalar value and slots", slot.loc)
    }

    // scalars cannot have slots
    else if (slot.ctype.isScalar)
    {
      if (slot.slots != null) err("Scalar slot '$slot.name' of type '$slot.ctype' cannot have slots", slot.loc)
    }

    // non-scalars cannot have value
    else
    {
      if (slot.val != null) err("Non-scalar slot '$slot.name' of type '$slot.ctype' cannot have scalar value", slot.loc)
    }
  }

  Void checkSpecMeta(ASpec x)
  {
    if (x.meta == null) return

    XetoUtil.specMetaReservedTags.each |name|
    {
      if (x.meta.has(name)) err("Spec '$x.name' cannot use reserved meta tag '$name'", x.loc)
    }

    checkDict(x.meta, null)
  }

  Void checkSpecQuery(ASpec x)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  Void checkInstance(ALib lib, Str name, AData x)
  {
    if (XetoUtil.isReservedInstanceName(name))
      err("Instance name '$name' is reserved", x.loc)

    if (name.startsWith("xmeta-"))
      checkXMeta(lib, name, x)

    checkDict(x, null)
  }

  Void checkXMeta(ALib lib, Str name, ADict x)
  {
    // set the lib hasXMeta flag
    lib.flags = lib.flags.or(MLibFlags.hasXMeta)

    // parse "xmeta-{lib}-{Name}"
    dash := name.index("-", 6)
    if (dash == null) err("Invalid xmeta id: $name", x.loc)
    libName:= name[6..<dash]
    specName := name[dash+1..-1]

    // cannot use xmeta inside my own lib (just put it in meta!)
    if (libName == lib.name)
    {
      err("Cannot specify xmeta for spec in lib itself", x.loc)
      return
    }

    // resolve from dependent lib
    XetoLib? depend := compiler.depends.libs[libName]
    if (depend == null)
    {
      err("Unknown lib for xmeta: $libName", x.loc)
      return
    }

    // check that spec exists in depend
    spec := depend.spec(specName, false)

    // check "Foo-enum" as special case
    if (spec == null && specName.endsWith("-enum"))
    {
      spec = depend.spec(specName[0..-6], false)
      if (spec != null && !spec.isEnum)
        return err("Enum xmeta for $name for non-enum type", x.loc)
    }

    if (spec == null)
    {
      if (specName.contains("."))
        err("Cannot use dotted spec names for xmeta: $libName::$specName", x.loc)
      else
        err("Unknown spec for xmeta: $libName::$specName", x.loc)
      return
    }
  }

//////////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////////

  Void checkData(AData x, CSpec? slot)
  {
    switch (x.nodeType)
    {
      case ANodeType.dict: checkDict(x, slot)
      case ANodeType.scalar: checkScalar(x, slot)
      case ANodeType.specRef: checkSpecRef(x)
      case ANodeType.dataRef: checkDataRef(x)
    }
  }

  Void checkScalar(AScalar x, CSpec? slot)
  {
    spec := slot ?: x.ctype
    CheckVal.checkScalar(spec, x.asm) |msg|
    {
      errSlot(slot, msg, x.loc)
    }
  }

  Void checkDict(ADict x, CSpec? slot)
  {
    spec := x.ctype

    if (spec.isList) checkList(x, slot)

    x.map.each |v, n|
    {
      checkData(v, spec.cslot(n, false))
    }

    spec.cslots |specSlot|
    {
      checkDictSlot(x, specSlot)
    }
  }

  Void checkList(ADict x, CSpec? slot)
  {
    spec := slot ?: x.ctype
    list := (Obj?[])x.asm
    CheckVal.checkList(spec, list) |msg|
    {
      errSlot(slot, msg, x.loc)
    }

    named := x.map.any |v, n| { !XetoUtil.isAutoName(n) }
    if (named) errSlot(slot, "List cannot contain named items", x.loc)
  }


  Void checkDictSlot(ADict x, CSpec slot)
  {
    if (slot.ctype.isChoice) return checkDictChoice(x, slot)

    val := x.get(slot.name)
    if (val == null)
    {
      // we don't check for missing slots in compiler,
      // instances automatically inherit from their spec
      return
    }

    if (!x.isMeta)
    {
      valType := val.ctype
      if (!valTypeFits(slot.ctype, valType, val.asm))
        errSlot(slot, "Slot type is '$slot.ctype', value type is '$valType'", x.loc)

      if (slot.isRef || slot.isMultiRef)
        checkRefTarget(slot, val)
    }
  }

  Bool valTypeFits(CSpec type, CSpec valType, Obj val)
  {
    // check if fits by nominal typing
    if (valType.cisa(type)) return true

    // TODO
    if (valType.qname == "sys::Str") return true

    // MultiRef may be either Ref or Ref[]
    if (type.isMultiRef)
    {
      if (val is Ref) return true
      if (val is List) return ((List)val).all |x| { x is Ref }
    }

    return false
  }

  Void checkRefTarget(CSpec slot, AData val)
  {
    of := slot.cof
    if (of == null) return true

    if (val is ADataRef)
    {
      instance := ((ADataRef)val).deref
      if (!instance.ctype.cisa(of))
        errSlot(slot, "Ref target must be '$of.qname', target is '$instance.ctype'", val.loc)
      return
    }

    if (val is ADict)
    {
      ((ADict)val).each |item| { checkRefTarget(slot, item) }
      return
    }
  }

  Void checkSpecRef(ASpecRef x)
  {
  }

  Void checkDataRef(ADataRef x)
  {
  }

  Void checkDictChoice(ADict x, CSpec slot)
  {
    MChoice.check(cns, slot, x.asm) |msg|
    {
      errSlot(slot, msg, x.loc)
    }
  }

}

