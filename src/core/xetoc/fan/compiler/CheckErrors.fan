//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Aug 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** CheckErrors is run late in the pipeline to perform AST validation
**
@Js
internal class CheckErrors : Step
{
  override Void run()
  {
    // instance and data value checks are performed by the Validate step
    if (isLib) checkLib(lib)
    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  Void checkLib(ALib x)
  {
    if (!XetoUtil.isLibName(x.name)) err("Invalid lib name '$x.name': " + XetoUtil.libNameErr(x.name), x.loc)
    checkLibMeta(lib)
    checkNameConflicts(x)
    x.tops.each |spec, name| { checkTop(spec) }
    x.ast.instances.each |instance, name| { checkInstance(x, name, instance) }
  }

  Void checkLibMeta(ALib x)
  {
    x.ast.meta.each |v, n|
    {
      // check that tags exists
      slot := compiler.libMetas.get(n, false)
      if (slot == null) return err("Undefined lib meta tag '$n'", x.loc)

      // check for reserved
      if (isReservedMeta(slot)) err("Reserved lib meta tag '$n'", x.loc)
    }
  }

  Void checkNameConflicts(ALib x)
  {
    tops := Str:Str[:]

    x.tops.each |spec, name|
    {
      topName := spec.name.lower
      dup := tops[topName]
      if (dup != null)
        err("Spec '$name' conflicts with $dup of the same case-insensitive name", x.loc)
      else
        tops[topName] = "spec"
    }

    x.ast.instances.each |instance, name|
    {
      topName := name.lower
      dup := tops[topName]
      if (dup != null)
        err("Instance '$name' conflicts with $dup of the same case-insensitive name", x.loc)
      else
        tops[topName] = "instance"
    }

    x.files.published.each |f|
    {
      uri := f.uri
      if (!XetoUtil.isChapter(uri)) return
      dup := tops[uri.basename.lower]
      if (dup != null)
        err("Markdown chapter '$uri.name' conflicts with $dup of the same case-insensitive name", x.loc)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Top Specs
//////////////////////////////////////////////////////////////////////////

  Void checkTop(ASpec x)
  {
    checkTopName(x)
    checkTypeInherit(x)
    checkSpec(x)
    if (x.isSugar) checkSugar(x)

    // maybe marks an optional slot; top level specs cannot be maybe
    // (excluding synthetic tops hoisted from inline types like Ref?)
    if (x.metaHas("maybe") && !x.parsedSyntheticRef)
      err("Top level spec cannot be maybe: $x.name", x.loc)
  }

  Void checkTopName(ASpec x)
  {
    if (x.name[0].isLower)
      err("Top level specs must start with upper case: $x.name", x.loc)

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

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  Void checkSpec(ASpec x)
  {
    checkSpecMeta(x)
    checkCovariant(x)
    checkMembers(x)
  }

  Void checkSpecMeta(ASpec x)
  {
    if (x.ast.meta == null) return

    x.ast.meta.each |v, n|
    {
      // check that tags exists
      slot := metas.get(n, false)
      if (slot == null) return err("Undefined meta tag '$n'", x.loc)

      // check for reserved
      if (isReservedMeta(slot)) err("Reserved spec meta tag '$n'", x.loc)
    }

    checkNamedLists(x.ast.meta)
  }

  Void checkCovariant(ASpec x)
  {
    b := x.base
    if (b == null) return
    xType := x.type
    bType := b.type

    // for mixins that add meta to slots, they cannot be typed; mixins
    // on sugar specs add constraints checked like any sugar member
    if (x.parent != null && x.parent.isMixin && !x.parent.isSugar && x.base.parent != null)
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

//////////////////////////////////////////////////////////////////////////
// Members
//////////////////////////////////////////////////////////////////////////

  Void checkMembers(ASpec x)
  {
    if (x.declared == null) return
    x.declared.each |slot| { checkMember(slot) }
  }

  Void checkMember(ASpec x)
  {
    checkMemberName(x)
    checkSpec(x)
    checkMemberType(x)
    checkMemberMeta(x)
    checkMemberVal(x)
    if (x.parent.isMixin) checkMixinMember(x)
    if (isSugarBody(x.parent)) checkSugarMember(x)
    if (x.parent.parent != null) checkNestedMember(x)
  }

  Void checkMemberName(ASpec x)
  {
    if (XetoUtil.isAutoName(x.name)) return
    if (!XetoUtil.isSlotName(x.name))
      err("Slots must start with lower case: $x.name", x.loc)
  }

  Void checkMemberType(ASpec slot)
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

  Void checkMemberMeta(ASpec slot)
  {
    if (slot.ast.meta == null) return

    // globals have no containing type to be required of, so maybe
    // is implied and cannot be declared
    if (slot.isGlobal && slot.ast.meta.get("maybe") != null)
      err("Global cannot be maybe: $slot.name", slot.loc)

    hasVal := slot.ast.meta.get("val") != null
    if (hasVal && slot.base != null && slot.base.meta.has("invariant"))
      err("Slot '$slot.name' is invariant and cannot declare new default value", slot.loc)
  }

  Void checkMemberVal(ASpec slot)
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

  Void checkMixinMember(ASpec x)
  {
    // mixins on sys::Spec
    if (!isSys && x.parent.base == ns.sys.spec)
    {
      if (!x.isMaybe) err("Spec mixin slot '$x.name' must be maybe type", x.loc)
    }
  }

  Void checkNestedMember(ASpec x)
  {
    if (x.isGlobal) err("Nested specs cannot declare global: $x.name", x.loc)
    //if (x.isQuery) err("Nested specs cannot declare query type: $x.name", x.loc)
  }

//////////////////////////////////////////////////////////////////////////
// Sugar
//////////////////////////////////////////////////////////////////////////

  ** Sugar spec is a conjunction of one nominal anchor plus constraints
  Void checkSugar(ASpec x)
  {
    if (x.isOr) return err("Sugar spec cannot be Or type: $x.name", x.loc)

    anchors := MSugar.anchors(x)
    if (anchors.size != 1) err("Sugar spec must have one nominal anchor: $x.name $anchors", x.loc)
  }

  ** Sugar rules apply to sugar types, their mixins, and the
  ** inline constraints of a query which act as anonymous sugar
  Bool isSugarBody(ASpec x)
  {
    if (x.parent == null) return x.isSugar
    return x.parent.isQuery
  }

  ** Sugar bodies declare queries, marker and invariant constraints,
  ** and defaults; every slot must resolve to a global in scope
  Void checkSugarMember(ASpec x)
  {
    if (x.isQuery) return
    if (x.isGlobal)
      err("Sugar spec cannot declare global '$x.name'", x.loc)
    else if (!isGlobalOverride(x))
      err("Sugar slot '$x.name' is not a global tag", x.loc)
    else if (x.type.isMarker && x.isMaybe)
      err("Sugar constraint '$x.name' cannot be maybe", x.loc)
    else if (!x.type.isMarker && x.val == null && !x.metaHas("val") && x.declared == null)
      err("Sugar slot '$x.name' must be marker, invariant, or default value", x.loc)
  }

  ** Does slot override a global directly or thru inherited slots
  private static Bool isGlobalOverride(ASpec x)
  {
    for (b := x.base; b != null && !b.isType; b = b.base)
      if (b.isGlobal) return true
    return false
  }

//////////////////////////////////////////////////////////////////////////
// Instances
//////////////////////////////////////////////////////////////////////////

  Void checkInstance(ALib lib, Str name, AInstance x)
  {
    if (XetoUtil.isReservedInstanceName(name))
      err("Instance name '$name' is reserved", x.loc)
    else if (!XetoUtil.isInstanceName(name))
      err("Instance name '$name' is invalid", x.loc)

    checkNamedLists(x)
  }

  ** Named list items are an AST only check: names do not survive
  ** reification, so the Validate step cannot see them
  Void checkNamedLists(AData x)
  {
    x.walkTopDown |n|
    {
      d := n as ADict
      if (d == null || !d.isList) return
      if (d.eachWhile(|v, name->Obj?| { XetoUtil.isAutoName(name) ? null : "named" }) != null)
        err("List cannot contain named items", d.loc)
    }
  }
}

