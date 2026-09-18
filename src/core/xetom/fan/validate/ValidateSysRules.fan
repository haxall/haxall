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

// Invoked directly by Validator fail fast
@Js internal const class ValidateSysMissingSpecRef : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Bool isApplicable(ValidateState s) { false } // special handling
  override Void onCheck(ValidateState s) { s.emit }
}

// Invoked directly by Validator fail fast
@Js internal const class ValidateSysUnknownSpecRef : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Bool isApplicable(ValidateState s) { false } // special handling
  override Void onCheck(ValidateState s) { s.emit }
}

@Js internal const class ValidateSysOverMaxVal : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return
    max := s.spec.meta["maxVal"] as Number
    if (max == null) return
    if (s.num > max) s.emit(Etc.dict1("maxVal", max))
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
    if (s.num < min) s.emit(Etc.dict1("minVal", min))
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
      s.emit(Etc.dict1("unit", min.unit.toStr))
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
      s.emit(Etc.dict1("unit", max.unit.toStr))
  }
}

@Js internal const class ValidateSysMissingSlot : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.val != null) return
    if (s.slotPath == null) return // never on the subject itself
    spec := s.spec
    if (spec.isMaybe) return
    if (spec.type.isChoice || spec.type.isQuery) return // their own rules
    s.emit(Etc.dict1("slotName", spec.name))
  }
}

