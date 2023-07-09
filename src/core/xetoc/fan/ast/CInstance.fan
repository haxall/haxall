//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 2023  Brian Frank  Creation
//

using xeto
using util

**
** CInstance is implemented by AInstance and to wrap other lib instance dicts
**
@Js
internal mixin CInstance : CNode
{
  ** Return if this an AST ADict
  abstract Bool isAst()

  ** Ref identifiers
  abstract Ref id()

  ** Type of dict
  abstract CSpec ctype()

}



