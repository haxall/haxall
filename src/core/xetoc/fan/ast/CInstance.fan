//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 2023  Brian Frank  Creation
//

using xeto
using util
using xetoEnv

**
** CInstance is implemented by AInstance and to wrap other lib instance dicts
**
internal mixin CInstance : CNode
{
  ** Return if this an AST ADict
  abstract Bool isAst()

  ** Type of dict
  abstract CSpec ctype()
}

**************************************************************************
** CInstanceWrap
**************************************************************************

internal const class CInstanceWrap : CInstance
{
  new make(Dict w, XetoSpec spec) { this.w = w; this.spec = spec }
  const Dict w
  const XetoSpec spec
  override Bool isAst() { false }
  override haystack::Ref id() { w->id }
  override CSpec ctype() { spec }
  override Obj asm() { id }
  override Str toStr() { id.toStr }
}

