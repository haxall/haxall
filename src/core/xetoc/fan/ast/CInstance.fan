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
  ** Wrap instance from dependency
  static CInstance? wrap(Dict? val)
  {
    if (val == null) return null
    return CInstanceWrap(val)
  }

  ** Return if this an AST ADict
  abstract Bool isAst()

  ** Ref identifiers
  abstract Ref id()

  ** Type of dict
  abstract CSpec ctype()

}

**************************************************************************
** CInstanceWrap
**************************************************************************

internal const class CInstanceWrap : CInstance
{
  new make(Dict w) { this.w = w }
  const Dict w
  override Bool isAst() { false }
  override Ref id() { w->id }
  override CSpec ctype() { (XetoSpec)w.spec }
  override Obj asm() { id }
}


