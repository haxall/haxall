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

// One class per sys ValidateRule instance, named "Validate" plus the
// rule name the same way every lib binds its rules - see
// ValidateRule.create.  So keep this file in sync with sys validation.xeto.

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

@Js internal const class ValidateMissingSpecRef : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateUnknownSpecRef : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateMissingSlot : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateUnknownType : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

@Js internal const class ValidateInvalidType : ValidateIntrinsicRule
{
  new make(ValidateRuleInit init) : super(init) {}
}

**************************************************************************
** Number Constraints
**************************************************************************

@Js internal const class ValidateOverMaxVal : ValidateRule
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

@Js internal const class ValidateUnderMinVal : ValidateRule
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

@Js internal const class ValidateMinValUnit : ValidateRule
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

@Js internal const class ValidateMaxValUnit : ValidateRule
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


@Js internal const class ValidateWrongUnit : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return
    unit := s.spec.meta["unit"] as Unit
    if (unit != null && unit != s.num.unit) s.emit
  }
}

@Js internal const class ValidateUnitless : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num?.unit == null) return
    if (s.spec.meta.has("unitless")) s.emit
  }
}

@Js internal const class ValidateWrongQuantity : ValidateRule
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
      key := ValidateWrongEnumKey.enumKey(s.val)
      if (key == null) return
      item := s.spec.type.enum.spec(key, false)
      if (item == null) return // wrongEnumKey's check
      uq := item.meta["quantity"] ?: "none"
      if (uq != q) emitReason(s, "'$key' has quantity of '$uq'")
    }
  }

  private Void emitReason(ValidateState s, Str reason) { s.emit(Etc.dict1("reason", reason)) }
}

**************************************************************************
** Scalar Constraints
**************************************************************************

@Js internal const class ValidatePatternMismatch : ValidateRule
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

@Js internal const class ValidateInvariantVal : ValidateRule
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

@Js internal const class ValidateWrongEnumKey : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    enum := s.spec.type
    if (!enum.isEnum) return
    key := enumKey(s.val)
    if (key == null) return // invalidType's check
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

**************************************************************************
** Size Constraints
**************************************************************************

@Js internal const class ValidateNonEmpty : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.spec.meta.missing("nonEmpty")) return
    list := s.val as List
    if (list != null) { if (list.isEmpty) s.emit; return }
    str := ValidateUnderMinSize.toSizeStr(s.val)
    if (str != null && str.trim.isEmpty) s.emit
  }
}

@Js internal const class ValidateUnderMinSize : ValidateRule
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

@Js internal const class ValidateOverMaxSize : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    max := CheckVal.toInt(s.spec.meta["maxSize"])
    if (max == null) return
    size := ValidateUnderMinSize.toSize(s.val)
    if (size != null && size > max) s.emit
  }
}

**************************************************************************
** Choices
**************************************************************************

@Js internal const class ValidateMissingChoice : ValidateRule
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

@Js internal const class ValidateConflictingChoice : ValidateRule
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

**************************************************************************
** Lists
**************************************************************************

@Js internal const class ValidateListNullItem : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    // non-null items are validated as their own frames by the walk
    of := s.listOf
    if (of == null || of.isMaybe) return
    s.list.each |v| { if (v == null) s.emit }
  }
}

**************************************************************************
** Refs
**************************************************************************

@Js internal const class ValidateUnresolvedRef : ValidateRule
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

@Js internal const class ValidateRefTargetSpec : ValidateRule
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

@Js internal const class ValidateRefTargetType : ValidateRule
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

**************************************************************************
** Queries
**************************************************************************

@Js internal const class ValidateMissingQuery : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    s.queryMatches?.each |qm|
    {
      if (qm.matches.isEmpty && !qm.constraint.isMaybe)
        s.emit(Etc.dictx("of", ofDis(s), "constraint", constraintDis(qm.constraint)))
    }
  }

  ** Display name for the query of type such as "Point"
  internal static Str ofDis(ValidateState s)
  {
    s.spec.of(false)?.name ?: s.spec.name
  }

  ** Display name for constraint; auto-named constraints use their type
  internal static Str constraintDis(Spec c)
  {
    XetoUtil.isAutoName(c.name) ? c.type.qname : c.name
  }
}

@Js internal const class ValidateAmbiguousQuery : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    s.queryMatches?.each |qm|
    {
      if (qm.matches.size > 1)
        s.emit(Etc.dictx(
          "of", ValidateMissingQuery.ofDis(s),
          "constraint", ValidateMissingQuery.constraintDis(qm.constraint),
          "matches", matchesDis(qm.matches)))
    }
  }

  ** Display for ambiguous matches as "@id dis" truncated for length
  private static Str matchesDis(Dict[] recs)
  {
    s := StrBuf()
    recs = recs.dup.sort |a, b| { a["id"] <=> b["id"] }
    for (i := 0; i<recs.size; ++i)
    {
      rec := recs[i]
      if (!s.isEmpty) s.add(", ")
      s.addChar('@').add(rec.id).add(" ").add(rec.dis.toCode)
      if (s.size > 50 && i+1 < recs.size)
        return s.add(", ${recs.size - i - 1} more ...").toStr
    }
    return s.toStr
  }
}

**************************************************************************
** TODO
**************************************************************************

@Js internal const class ValidateSugarConstraint : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s) {}
}

@Js internal const class ValidateListNamedItem : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s) {}
}

