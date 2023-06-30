//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Feb 2023  Brian Frank  Creation
//

using util

**
** AST object reference to a named Spec
**
@Js
internal class ARef
{
  ** Constructor
  new make(FileLoc loc, AName name)
  {
    this.loc = loc
    this.name = name
  }

  ** Construct for resolved
  new makeResolved(FileLoc loc, CSpec spec)
  {
    this.loc = loc
    this.name = AName(null, spec.name)
    this.resolvedRef = spec
  }

  ** Source code location
  const FileLoc loc

  ** Qualified/unqualified name
  const AName name

  ** Return qualified/unqualified name
  override Str toStr() { resolvedRef?.qname ?: name.toStr }

  ** Is this reference already resolved
  Bool isResolved() { resolvedRef != null }

  ** Get the resolved spec
  CSpec resolved() { resolvedRef ?: throw UnresolvedErr("$name [$loc]") }

  ** Resolved assmbled XetoSpec
  XetoSpec asm() { resolved.asm }

  ** Resolve to its spec
  Void resolve(CSpec x) { this.resolvedRef = x }

  private CSpec? resolvedRef
}