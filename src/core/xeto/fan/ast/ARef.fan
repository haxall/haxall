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

  ** Is this resolved to an internal AST node
  Bool isResolvedInternal() { referent != null && referentInternal != null }

  ** Is this resolved to an external dependency
  Bool isResolvedExternal() { referent != null && referentInternal == null }

  ** Resolved reference or raise UnresolvedErr
  override XetoType asm() { referent ?: throw UnresolvedErr("$name [$loc]") }

  ** Resovled reference to an internal AST node
  ASpec resolvedInternal() { referentInternal ?: throw UnresolvedErr("$name [$loc]") }

  ** Resolved qname UnresolvedErr
  Str qname() { qnameRef ?: throw UnresolvedErr("$name [$loc]") }

  ** Resolve via an internal AST type
  Void resolveInternal(AType x)
  {
    this.referent = x.asm
    this.referentInternal = x
    this.qnameRef = x.qname
  }

  ** Resolve via an external dependency type
  Void resolveExternal(XetoType x)
  {
    this.referent = x
    this.qnameRef = x.qname
  }

  ** Resolved reference
  private XetoType? referent

  ** Resolve reference to internal AST node
  private ASpec? referentInternal

  ** Resolved qualified name
  private Str? qnameRef

}