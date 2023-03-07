//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Feb 2023  Brian Frank  Creation
//

using util

**
** AST object reference to a named DataSpec
**
@Js
internal class ARef : ANode
{
  ** Constructor
  new make(FileLoc loc, AName name)
  {
    this.loc = loc
    this.name = name
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.ref }

  ** Source code location
  const override FileLoc loc

  ** Qualified/unqualified name
  const AName name

  ** Walk myself
  override Void walk(|ANode| f) { f(this) }

  ** Return qualified/unqualified name
  override Str toStr() { qnameRef?.toStr ?: name.toStr }

  ** Is this reference already resolved
  Bool isResolved() { referent != null }

  ** Resolved reference or raise UnresolvedErr
  override XetoType asm() { referent ?: throw UnresolvedErr("$name [$loc]") }

  ** Resolved qname UnresolvedErr
  Str qname() { qnameRef ?: throw UnresolvedErr("$name [$loc]") }

  ** Resolve via an internal AST type
  Void resolveAst(AType x)
  {
    this.referent = x.asm
    this.qnameRef = x.qname
  }

  ** Resolve via an external dependency type
  Void resolveDepend(XetoType x)
  {
    this.referent = x
    this.qnameRef = x.qname
  }

  ** Resolved reference
  private XetoType? referent

  ** Resolved qualified name
  private Str? qnameRef

}