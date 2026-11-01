//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Nov 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

// One class per pi ValidateRule instance, named "Validate" plus the rule
// name the same way every lib binds its rules - see ValidateRule.create.
// So keep this file in sync with pi validation.xeto.

**************************************************************************
** SketchSrc
**************************************************************************

** Build-only rule which checks SketchSrc compiles.  The sketch compiler
** lives in studio's sketch pod, so it is reached by reflection and the
** rule does nothing when that pod is not installed.
@Js internal const class ValidateInvalidSketchSrc : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Bool isBuildOnly() { true }
  override Void onCheck(ValidateState s)
  {
    src := s.val?.toStr
    if (src == null || compileCheck == null) return
    ((FileLocErr[])compileCheck.call(s.ns, src)).each |e|
    {
      s.emit(Etc.dict1("err", "line $e.loc.line: $e.msg"))
    }
  }
  private const Method? compileCheck := Slot.findMethod("sketch::MSketch.check", false)
}
