//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//   3 Jul 2023  Brian Frank  Redesign the AST
//

using util
using xeto

**
** AST for reference to either a type or an instance
**
@Js
internal abstract class ARef : AData
{
  ** Constructor
  new make(FileLoc loc, AName name)
    : super(loc, null)
  {
    this.name = name
  }

  ** Is data value already assembled
  override final Bool isAsm() { isResolved }

  ** Qualified or unqualified name
  const AName name

  ** Is this an ARef type
  override Bool isRef() { true }

  ** Return debug string
  override Str toStr() { name.toStr }

  ** Is this reference resolved
  abstract Bool isResolved()

  ** Tree walk
  override Void walk(|ANode| f)
  {
    f(this)
  }
}

**************************************************************************
** ASpecRef
**************************************************************************

**
** AST for signature to reference a spec
**
@Js
internal class ASpecRef : ARef
{
  ** Constructor
  new make(FileLoc loc, AName name) : super(loc, name) {}

  ** Construct for resolved
  new makeResolved(FileLoc loc, CSpec spec)
    : super.make(loc, ASimpleName(null, spec.name)) // don't create full AName
  {
    this.resolvedRef = spec
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.specRef }

  ** Is this reference resolved
  override Bool isResolved() { resolvedRef != null }

  ** Assembled scalar value
  override Spec asm() { deref.asm }

  ** Resolve to its spec
  Void resolve(CSpec x) { this.resolvedRef = x }

  ** Dereference the resolved type spec
  CSpec deref() { resolvedRef ?: throw NotReadyErr(toStr) }

  ** Resolved spec
  private CSpec? resolvedRef

}

**************************************************************************
** ADataRef
**************************************************************************

**
** AST for reference to a qualified instance data dict
**
@Js
internal class ADataRef : ARef
{
  ** Constructor
  new make(FileLoc loc, AName name) : super(loc, name) {}

  ** Node type
  override ANodeType nodeType() { ANodeType.dataRef }

  ** Assembled scalar value
  override Obj asm() { throw Err("TODO") }

  ** Is this reference resolved
  override Bool isResolved() { true } // TODO
}


