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

