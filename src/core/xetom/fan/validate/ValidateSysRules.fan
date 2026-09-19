//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Sep 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

@Js internal const class ValidateSysTodo : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s) {}
}

**************************************************************************
** Intrinsic Rules (handled by Validator itself)
**************************************************************************

@Js internal abstract const class ValidateIntrinsicRule : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override final Bool isApplicable(ValidateState s) { false }
  override final Void onCheck(ValidateState s) { throw Err("Not used") }
  Void emit(ValidateState s, Dict args := Etc.dict0) { s.emitRule(this, args) }
}

@Js internal const class ValidateSysMissingSpecRef : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateSysUnknownSpecRef : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateSysMissingSlot : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateSysUnknownType : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateSysInvalidType : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

**************************************************************************
** Applied Rules
**************************************************************************

@Js internal const class ValidateSysOverMaxVal : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return
    max := s.spec.meta["maxVal"] as Number
    if (max == null) return
    if (s.num > max) s.emit
  }
}

@Js internal const class ValidateSysUnderMinVal : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return
    min := s.spec.meta["minVal"] as Number
    if (min == null) return
    if (s.num < min) s.emit
  }
}

@Js internal const class ValidateSysMinValUnit : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return
    min := s.spec.meta["minVal"] as Number
    if (min?.unit != null && min.unit != s.num.unit)
      s.emit
  }
}

@Js internal const class ValidateSysMaxValUnit : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return
    max := s.spec.meta["maxVal"] as Number
    if (max?.unit != null && max.unit != s.num.unit)
      s.emit
  }
}


@Js internal const class ValidateSysWrongUnit : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return
    unit := s.spec.meta["unit"] as Unit
    if (unit != null && unit != s.num.unit) s.emit
  }
}

@Js internal const class ValidateSysUnitless : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num?.unit == null) return
    if (s.spec.meta.has("unitless")) s.emit
  }
}

@Js internal const class ValidateSysWrongQuantity : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    q := s.spec.meta["quantity"]
    if (q == null) return

    // number unit quantity
    if (s.num != null)
    {
      unit := s.num.unit
      if (unit == null) return emitReason(s, "no unit specified")
      uq := UnitQuantity.unitToQuantity[unit]
      if (uq == null) return emitReason(s, "'$unit' has no quantity")
      if (uq != q) return emitReason(s, "'$unit' has quantity of '$uq'")
      return
    }

    // unit enum quantity
    if (s.spec.type.qname == "sys::Unit")
    {
      key := ValidateSysWrongEnumKey.enumKey(s.val)
      if (key == null) return
      item := s.spec.type.enum.spec(key, false)
      if (item == null) return // wrongEnumKey's check
      uq := item.meta["quantity"] ?: "none"
      if (uq != q) emitReason(s, "'$key' has quantity of '$uq'")
    }
  }

  private Void emitReason(ValidateState s, Str reason) { s.emit(Etc.dict1("reason", reason)) }
}

@Js internal const class ValidateSysPatternMismatch : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    pattern := s.spec.meta["pattern"] as Str
    if (pattern == null) return
    if (s.spec.type.isEnum) return // enums validate by key
    str := toPatternStr(s.val)
    if (str == null) return
    if (!Regex(pattern).matches(str)) s.emit
  }

  ** String encoding to check or null if not string encoded
  private static Str? toPatternStr(Obj? val)
  {
    if (val is Str) return val
    if (val is Scalar) return val.toStr
    return null
  }
}

@Js internal const class ValidateSysInvariantVal : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.spec.meta.missing("invariant")) return

    // check actual against expected invariant value, narrowing
    // the expected value when using less than full fidelity
    expect := s.spec.meta["val"]
    if (expect == null) return
    if (Etc.eq(expect, s.val)) return
    narrow := s.fidelity.coerce(expect)
    if (narrow !== expect && Etc.eq(narrow, s.val)) return

    s.emit(Etc.dict1("expect", expect))
  }
}

@Js internal const class ValidateSysEnumValType : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (!s.spec.type.isEnum) return
    if (ValidateSysWrongEnumKey.enumKey(s.val) == null) s.emit
  }
}

@Js internal const class ValidateSysWrongEnumKey : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    enum := s.spec.type
    if (!enum.isEnum) return
    key := enumKey(s.val)
    if (key == null) return // enumValType's check
    if (enum.enum.spec(key, false) == null) s.emit
  }

  ** Map enum value to its string key or null
  internal static Str? enumKey(Obj? val)
  {
    if (val is Str)      return val
    if (val is Scalar)   return ((Scalar)val).val
    if (val is Enum)     return ((Enum)val).name
    if (val is Unit)     return ((Unit)val).symbol
    if (val is TimeZone) return ((TimeZone)val).name
    return null
  }
}

@Js internal const class ValidateSysNonEmpty : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.spec.meta.missing("nonEmpty")) return
    list := s.val as List
    if (list != null) { if (list.isEmpty) s.emit; return }
    str := ValidateSysUnderMinSize.toSizeStr(s.val)
    if (str != null && str.trim.isEmpty) s.emit
  }
}

@Js internal const class ValidateSysUnderMinSize : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    min := CheckVal.toInt(s.spec.meta["minSize"])
    if (min == null) return
    size := toSize(s.val)
    if (size != null && size < min) s.emit
  }

  ** Size of string encoded or list value or null
  internal static Int? toSize(Obj? val)
  {
    if (val is List) return ((List)val).size
    return toSizeStr(val)?.size
  }

  ** String encoding to size or null if not string encoded
  internal static Str? toSizeStr(Obj? val)
  {
    if (val is Str) return val
    if (val is Scalar) return val.toStr
    return null
  }
}

@Js internal const class ValidateSysOverMaxSize : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    max := CheckVal.toInt(s.spec.meta["maxSize"])
    if (max == null) return
    size := ValidateSysUnderMinSize.toSize(s.val)
    if (size != null && size > max) s.emit
  }
}

@Js internal const class ValidateSysMissingChoice : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    slot := s.spec
    if (!slot.isChoice || slot.isMaybe) return
    dict := s.parentDict
    if (dict == null) return
    acc := Spec[,]
    MChoice.findSelections((CNamespace)s.ns, slot, dict, acc)
    if (acc.isEmpty) s.emit(Etc.dict1("choice", slot.type.id))
  }
}

@Js internal const class ValidateSysConflictingChoice : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    slot := s.spec
    if (!slot.isChoice) return
    dict := s.parentDict
    if (dict == null) return
    acc := Spec[,]
    MChoice.findSelections((CNamespace)s.ns, slot, dict, acc)
    if (MChoice.isConflict(slot, acc))
      s.emit(Etc.dictx("choice", slot.type.id, "selections", acc.join(", ") { it.name }))
  }
}

@Js internal const class ValidateSysUnresolvedRef : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    s.refs.each |x|
    {
      if (x.target == null) s.emit(Etc.dict1("ref", x.ref))
    }
  }
}

@Js internal const class ValidateSysRefTargetSpec : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    of := s.spec.of(false)
    if (of == null) return
    s.refs.each |x|
    {
      if (x.target == null) return // unresolvedRef's check

      // target spec tag must be present and resolvable; temp libs
      // are not in the namespace so let them fall thru to type check
      specRef := x.target["spec"] as Ref
      if (specRef == null) return s.emit(Etc.dict1("ref", x.ref))
      if (specRef.id == of.qname) return
      if (s.ns.spec(specRef.id, false) == null && !specRef.id.startsWith("temp"))
        s.emit(Etc.dict1("ref", x.ref))
    }
  }
}

@Js internal const class ValidateSysRefTargetType : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    of := s.spec.of(false)
    if (of == null) return
    s.refs.each |x|
    {
      if (x.target == null) return // unresolvedRef's check

      // short circuit if qnames match exactly (useful for testing too)
      specRef := x.target["spec"] as Ref
      if (specRef == null) return // refTargetSpec's check
      if (specRef.id == of.qname) return

      // check target type; unresolvable temp lib spec is a mismatch
      targetSpec := s.ns.spec(specRef.id, false)
      if (targetSpec == null && !specRef.id.startsWith("temp")) return // refTargetSpec's
      if (targetSpec == null || !targetSpec.isa(of))
        s.emit(Etc.dictx("ref", x.ref, "targetSpec", specRef))
    }
  }
}
