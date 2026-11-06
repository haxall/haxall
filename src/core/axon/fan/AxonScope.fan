//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Oct 2009  Brian Frank  Creation
//   4 Nov 2026  Brian Frank  Split out from CallFrame
//

using util
using xeto
using haystack

**
** AxonScope manages the lexical variable scope of the axon context.
**
@NoDoc @Js
class AxonScope
{
  ** Create new root scope with no variables
  new make() { this.vars = Str:Obj[:] }

  ** Create new scope nested in the given parent scope
  internal new makeNested(AxonScope parent)
  {
    this.parent = parent
    this.vars   = Str:Obj[:]
  }

  ** Create readonly scope for a const func from toConstVars
  internal new makeConst(Str:Obj vars) { this.vars = vars }

  ** Flag to allow re-defines such in a REPL
  Bool redefines

  ** Return if given variable name is defined in the scope chain
  Bool has(Str name)
  {
    v := lookup(name)
    return v !== notFound && v !== notConst
  }

  ** Get variable in the scope chain or null if not found
  Obj? get(Str name)
  {
    v := lookup(name)
    return v === notFound || v === notConst ? null : v
  }

  ** Return effective map of all variables in scope chain
  Str:Obj? effective()
  {
    acc := Str:Obj?[:]
    effectiveRaw.each |v, n| { if (v !== notConst) acc[n] = v === nullVal ? null : v }
    return acc
  }

  ** Set variable in this scope (no checking)
  This set(Str name, Obj? val)
  {
    vars[name] = val ?: nullVal
    return this
  }

  ** Define a new variable in this scope.
  ** Return null on success or error message if already defined.
  Str? define(Str name, Obj? val)
  {
    if (vars.containsKey(name) && !redefines) return "Symbol already bound '$name' (use = to reassign)"
    vars[name] = val ?: nullVal
    return null
  }

  ** Assign to an existing defined variable in the scope chain.
  ** Return null on success or error message if not defined or readonly.
  Str? assign(Str name, Obj? val)
  {
    if (vars.containsKey(name))
    {
      if (vars.isRO) return "Cannot assign captured var '$name' in const func"
      vars[name] = val ?: nullVal
      return null
    }
    if (parent == null) return "Unknown symbol '$name'"
    return parent.assign(name, val)
  }

  ** Get variable in the scope chain or notFound if not defined, or
  ** notConst if captured by a const func but could not be immutable
  internal Obj? lookup(Str name)
  {
    v := vars.get(name)
    if (v != null) return v === nullVal ? null : v
    if (parent == null) return notFound
    return parent.lookup(name)
  }

  ** Return immutable snapshot of all variables in the scope chain
  ** for makeConst; variables which cannot be immutable are marked
  ** so they raise an error if used
  internal Str:Obj toConstVars()
  {
    effectiveRaw.map |v->Obj|
    {
      if (v.isImmutable) return v
      if (v is List || v is Map)
      {
        try return v.toImmutable
        catch (NotImmutableErr e) {}
      }
      return notConst
    }.toImmutable
  }

  ** Effective map of all variables in scope chain with markers
  private Str:Obj effectiveRaw()
  {
    acc := parent?.effectiveRaw ?: Str:Obj[:]
    vars.each |v, n| { acc[n] = v }
    return acc
  }

  ** Debug dict of the variables defined directly in this scope; values
  ** which are not immutable are converted to their string
  internal Dict toDict()
  {
    acc := Str:Obj?[:]
    vars.each |v, n|
    {
      if (v === notConst) return
      if (v === nullVal) acc[n] = null
      else acc[n] = v.isImmutable ? v : v.toStr
    }
    return Etc.makeDict(acc)
  }

  ** Debug string
  override Str toStr() { "AxonScope [vars: $vars.keys]" }

  ** Value returned by lookup if name is not defined
  internal static const Obj notFound := ScopeMarker("notFound")

  ** Stored in vars for null values so lookup is one hash lookup
  private static const Obj nullVal := ScopeMarker("null")

  ** Stored in const vars for values which could not be made immutable
  internal static const Obj notConst := ScopeMarker("notConst")

  ** Parent scope in the chain or null if this is root scope
  private AxonScope? parent

  ** Variables in this scope with nulls stored as nullVal
  private Str:Obj vars
}

**************************************************************************
** ScopeMarker
**************************************************************************

@Js internal const class ScopeMarker
{
  new make(Str name) { this.name = name }
  const Str name
  override Str toStr() { name }
}
