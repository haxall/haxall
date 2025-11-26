//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Aug 2023  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetom

**
** CheckErrors is run late in the pipeline to perform AST validation
**
@Js
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
    x.ast.instances.each |instance, name| { checkInstance(x, name, instance) }
  }

  Void checkLibMeta(ALib x)
  {
    x.ast.meta.each |v, n|
    {
      if (XetoUtil.isReservedLibMetaName(n))
      {
        err("Reserverd lib meta tag '$n'", x.loc)
      }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  Void checkTop(ASpec x)
  {
    if (x.name[0].isLower) err("Lib specs must start with upper case: $x.name", x.loc)

    checkTopName(x)
    checkTypeInherit(x)
    checkSpec(x)
    if (x.isType)
      checkType(x)
    else
      checkMixin(x)
  }

  Void checkTopName(ASpec x)
  {
    if (lib.ast.instances[x.name] != null || lib.ast.instances[x.name.lower] != null)
      err("Spec '$x.name' conflicts with instance of the same name", x.loc)

    if (XetoUtil.isReservedSpecName(x.name))
      err("Spec name '$x.name' is reserved", x.loc)
  }

  Void checkTypeInherit(ASpec x)
  {
    if (!x.isType) return
    if (x.base == null) return // Obj
    base := x.base

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
    Spec? dict := null
    Spec? list := null
    Spec? scalar := null

    x.ofs.each |of|
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

  Void checkCanInheritFrom(ASpec x, Spec base, FileLoc loc)
  {
    // enums are effectively sealed even in same lib
    if (base.isEnum)
      return err("Cannot inherit from Enum type '$base.name'", loc)

    // cannot subtype from sealed types in external libs
    // Note: we allow this in cases like <of:Ref<of:Site>>
    if (base.meta.has("sealed") && !base.isAst && !x.parsedSyntheticRef)
      return err("Cannot inherit from sealed type '$base.name'", loc)
  }


  Void checkSpec(ASpec x)
  {
    checkSpecMeta(x)
    checkCovariant(x)
    if (x.isQuery) return checkSpecQuery(x)
    checkSlots(x)
  }

  Void checkCovariant(ASpec x)
  {
    b := x.base
    if (b == null) return
    xType := x.type
    bType := b.type

    // for mixins that add meta to slots, they cannot be typed
    if (x.parent != null && x.parent.isMixin && x.base.parent != null)
    {
      if (x.base.isGlobal)
        err("Mixin extend global: $x.name", x.loc)
      else if (!xType.isMarker)
        err("Mixin cannot specify slot type: $x.name", x.loc)
      x.typeRef = ASpecRef(x.loc, bType)
      return
    }

    // verify type is covariant
    if (!xType.isa(bType) && !isFieldOverrideOfMethod(b, x))
      errCovariant(x, "type '$xType' conflicts", "of type '$bType'")

    // check "of"
    xOf := x.of(false)
    bOf := b.of(false)
    if (xOf != null && bOf != null && !xOf.isa(bOf))
      errCovariant(x, "of's type '$xOf' conflicts", "of's type '$bOf'")

    // check "minVal"
    xMinVal := XetoUtil.toFloat(x.meta.get("minVal"))
    bMinVal := XetoUtil.toFloat(b.meta.get("minVal"))
    if (xMinVal != null && bMinVal != null && xMinVal < bMinVal)
      errCovariant(x, "minVal '$xMinVal' conflicts", "minVal '$bMinVal'")

    // check "maxVal"
    xMaxVal := XetoUtil.toFloat(x.meta.get("maxVal"))
    bMaxVal := XetoUtil.toFloat(b.meta.get("maxVal"))
    if (xMinVal != null && bMinVal != null && xMinVal < bMinVal)
      errCovariant(x, "maxVal '$xMaxVal' conflicts", "maxVal '$bMaxVal'")

    // check "quantity"
    xQuantity := x.meta.get("quantity")
    bQuantity := b.meta.get("quantity")
    if (xQuantity != bQuantity && bQuantity != null)
      errCovariant(x, "quantity '$xQuantity' conflicts", "quantity '$bQuantity'")

    // check "unit"
    xUnit:= x.meta.get("unit")
    bUnit := b.meta.get("unit")
    if (xUnit != bUnit && bUnit != null)
      errCovariant(x, "unit '$xUnit' conflicts", "unit '$bUnit'")
  }

  Bool isFieldOverrideOfMethod(Spec b, ASpec x)
  {
    // we allow a field to override a method if it matches base func return type
    isOverride := x.isInterfaceSlot && b.type.isFunc && !x.type.isFunc
    if (!isOverride) return false

    // check that x type is covariant to b func returns type
    bReturns := b.member("returns")?.type
    if (!x.type.isa(bReturns))
      err("Type mismatch in field '$x.name' override of method: $x.type != $bReturns", x.loc)
    return true
  }

  Void errCovariant(ASpec x, Str msg1, Str msg2)
  {
    // if the spec is a variable/macro/template construct then ignore
    if (isMacro(x)) return

    if (x.isSlot && x.base.isGlobal)
      err("Slot '$x.name' $msg1 global '$x.base.qname' $msg2", x.loc)
    else if (x.isSlot)
      err("Slot '$x.name' $msg1 inherited slot '$x.base.qname' $msg2", x.loc)
    else
      err("Type '$x.name' $msg1 inherited type '$x.base.qname' $msg2", x.loc)
  }

  Bool isMacro(ASpec x)
  {
    x.type.qname.startsWith("sys.template::")
  }

  Void checkSlots(ASpec x)
  {
    if (x.declared == null) return
    x.declared.each |slot| { checkSlot(slot) }
  }

  Void checkSlot(ASpec x)
  {
    checkSpec(x)
    checkSlotType(x)
    checkSlotMeta(x)
    checkSlotVal(x)
    if (x.isGlobal && x.parent.isMixin) err("Mixin cannot decalre global: $x.name", x.loc)
  }

  Void checkSlotType(ASpec slot)
  {
    // don't run these checks for enum items
    if (slot.parent.isEnum) return

    // lists cannot have slots
    if (slot.parent.isList && !XetoUtil.isAutoName(slot.name))
      err("List specs cannot define slots", slot.loc)

    // choices can have only markers
    if (slot.parent.isChoice && !slot.type.isMarker)
      err("Choice slot '$slot.name' must be marker type", slot.loc)
  }

  Void checkSlotMeta(ASpec slot)
  {
    if (slot.ast.meta == null) return

    hasVal := slot.ast.meta.get("val") != null
    if (hasVal && slot.base != null && slot.base.meta.has("fixed"))
      err("Slot '$slot.name' is fixed and cannot declare new default value", slot.loc)
  }

  Void checkSlotVal(ASpec slot)
  {
    // slots of type Obj can have either scalar or slots (but not both)
    if (isObj(slot.type))
    {
      // this actually should never happen because we don't parse this case
      if (slot.val != null && slot.declared != null)
        err("Cannot have both scalar value and slots", slot.loc)
    }

    // scalars cannot have slots
    else if (slot.type.isScalar)
    {
      if (slot.declared != null) err("Scalar slot '$slot.name' of type '$slot.type' cannot have slots", slot.loc)
    }

    // non-scalars cannot have value
    else
    {
      if (slot.val != null) err("Non-scalar slot '$slot.name' of type '$slot.type' cannot have scalar value", slot.loc)
    }
  }

  Void checkSpecMeta(ASpec x)
  {
    if (x.ast.meta == null) return

    x.ast.meta.each |v, n|
    {
      if (XetoUtil.isReservedSpecMetaName(n))
      {
        err("Reserved spec meta tag '$n'", x.loc)
        return
      }

      // check that tags exists
      slot := metas.get(n, false)
      if (slot == null) err("Undefined meta tag '$n'", x.loc)
    }

    checkDict(x.ast.meta, null)
  }

  Void checkType(ASpec x)
  {
  }

  Void checkMixin(ASpec x)
  {
    // TODO
  }

  Void checkSpecQuery(ASpec x)
  {
  }

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  Void checkInstance(ALib lib, Str name, AInstance x)
  {
    if (XetoUtil.isReservedInstanceName(name))
      err("Instance name '$name' is reserved", x.loc)

    checkDict(x, null)
  }

//////////////////////////////////////////////////////////////////////////
// Data
//////////////////////////////////////////////////////////////////////////

  Void checkData(AData x, Spec? slot)
  {
    switch (x.nodeType)
    {
      case ANodeType.dict: checkDict(x, slot)
      case ANodeType.scalar: checkScalar(x, slot)
      case ANodeType.specRef: checkSpecRef(x)
      case ANodeType.dataRef: checkDataRef(x)
    }
  }

  Void checkScalar(AScalar x, Spec? slot)
  {
    spec := slot ?: x.type
    checkVal.check(spec, x.asm) |msg|
    {
      errSlot(slot, msg, x.loc)
    }
  }

  Void checkDict(ADict x, Spec? slot)
  {
    spec := x.type

    if (spec.isList) checkList(x, slot)

    x.each |v, n|
    {
      checkData(v, spec.member(n, false))
    }

    spec.members.each |memberSpec|
    {
      checkDictSlot(x, memberSpec)
    }
  }

  Void checkList(ADict x, Spec? slot)
  {
    spec := slot ?: x.type
    list := x.asm as List

    if (list == null)
    {
      echo("WARN: need to checkList on $x.asm`.typeof")
      return
    }

    // check spec meta notEmpty, minSize, maxSize
    checkVal.check(spec, list) |msg|
    {
      errSlot(slot, msg, x.loc)
    }

    // determine if we need to check item type against of
    of := spec.of(false)
    if (spec.name == "ofs") of = null
    if (spec.isMultiRef)  of = null
    while (of != null && XetoUtil.isAutoName(of.name))
      of = of?.base

    // walk thru each item and check auto-name and optionally item type
    named := false
    x.each |v, n|
    {
      if (!XetoUtil.isAutoName(n)) named = true
      if (of != null && !v.type.isa(of))
      {
        errSlot(slot, "List item type is '$of', item type is '$v.type'", v.loc)
      }
    }
    if (named) errSlot(slot, "List cannot contain named items", x.loc)
  }

  Void checkDictSlot(ADict x, Spec slot)
  {
    if (slot.type.isChoice) return checkDictChoice(x, slot)

    val := x.get(slot.name)
    if (val == null)
    {
      // we don't check for missing slots in compiler,
      // instances automatically inherit from their spec
      return
    }

    if (!x.isSpecMeta)
    {
      valType := val.type
      if (!valTypeFits(slot.type, valType, val.asm))
      {
        memberType := slot.isGlobal ? "Global" : "Slot"
        errSlot(slot, "$memberType type is '$slot.type', value type is '$valType'", x.loc)
      }

      if (slot.isRef || slot.isMultiRef)
        checkRefTarget(slot, val)
    }
  }

  Bool valTypeFits(Spec type, Spec valType, Obj val)
  {
    // check if fits by nominal typing
    if (valType.isa(type)) return true

    // MultiRef may be either Ref or Ref[]
    if (type.isMultiRef)
    {
      if (val is Ref) return true
      if (val is List) return ((List)val).all |x| { x is Ref }
    }

    return false
  }

  Void checkRefTarget(Spec slot, AData val)
  {
    of := slot.of(false)
    if (of == null) return true

    if (val is ADataRef)
    {
      instance := ((ADataRef)val).deref
      if (!instance.type.isa(of))
        errSlot(slot, "Ref target must be '$of.qname', target is '$instance.type'", val.loc)
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

  Void checkDictChoice(ADict x, Spec slot)
  {
    MChoice.check(cns, slot, x.asm) |msg|
    {
      errSlot(slot, msg, x.loc)
    }
  }

  const CheckVal checkVal := CheckVal(Etc.dict0)
}

