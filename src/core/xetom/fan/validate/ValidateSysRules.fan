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

@Js internal const class ValidateSysOverMaxVal : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.num == null) return null
    max := s.spec.meta["maxVal"] as Number
    if (max == null) return null
    if (s.num > max) s.emit(Etc.dict1("maxVal", max))
  }
}

