//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Nov 2026  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** Build-only rule which checks AxonSrc parses.  Source is parsed as a
** pipeline: a func body or expression is a pipeline of one, and ion
** UiFunc bodies chain exprs with "|".  So server code which wrongly
** uses "|" passes here and only fails at runtime.
**
@Js
internal const class ValidateInvalidAxonSrc : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}

  override Bool isBuildOnly() { true }

  private static const FileLoc loc := FileLoc("axon")

  override Void onCheck(ValidateState s)
  {
    src := s.val?.toStr
    if (src == null) return
    try
      Parser(src.in, loc).parsePipeline
    catch (SyntaxErr e)
      s.emit(Etc.dict1("err", "line $e.loc.line: $e.msg"))
  }
}
