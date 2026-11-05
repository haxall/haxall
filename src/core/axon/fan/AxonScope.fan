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
  ** Create new scope with no variables
  new make0()
  {
    this.vars = Str:Obj?[:]
  }

  ** Create new scope with one variable
  new make1(Str n0, Obj? v0)
  {
    this.vars = Str:Obj?[n0: v0 ?: nullSentinel]
  }

  ** Create new scope with two variables
  new make2(Str n0, Obj? v0, Str n1, Obj? v1)
  {
    this.vars = Str:Obj?[n0: v0 ?: nullSentinel, n1: v1 ?: nullSentinel]
  }

  ** Create new scope with given map
  internal new makeMap(Str:Obj? vars)
  {
    this.vars = vars.isEmpty ? vars : vars.map |v| { v == null ? nullSentinel : v }
  }

  ** Create new scope with copy of variables from toConstVars
  internal new makeConst(Str:Obj vars)
  {
    this.vars = vars.dup
  }

  ** Create new scope with given lexical scope parent and initial variables
  internal new makeNested(AxonScope? parent, Str:Obj? vars)
  {
    this.parent = parent
    this.vars   = vars.isEmpty ? vars : vars.map |v| { v == null ? nullSentinel : v }
  }

  ** Flag to allow re-defines such in a REPL
  Bool redefines

  ** Parent scope in the chain or null if this is root scope
  AxonScope? parent { private set }

  ** Return if given variable name is defined in the scope chain
  Bool has(Str name)
  {
    getRaw(name) != null
  }

  ** Get variable in the scope chain or null if not found
  Obj? get(Str name)
  {
    v := getRaw(name)
    return v === nullSentinel ? null : v
  }

  ** Get variable in the scope chain and return nullSentinel if the
  ** value is null.  Return null only if name is not defined by scope.
  internal Obj? getRaw(Str name)
  {
    v := vars.get(name)
    if (v != null) return v
    return parent?.getRaw(name)
  }

  ** Return effective map of all variables in scope
  Str:Obj? effective()
  {
    effectiveRaw.map |v->Obj?| { v === nullSentinel ? null : v }
  }

  ** Return immutable copy of all variables in scope which can be made
  ** immutable to create new scopes via makeConst
  internal Str:Obj toConstVars()
  {
    effectiveRaw.mapNotNull |v->Obj?|
    {
      try
        return v.toImmutable
      catch (NotImmutableErr e)
        return null
    }.toImmutable
  }

  ** Effective map of all variables with nulls as nullSentinel
  private Str:Obj effectiveRaw()
  {
    acc := vars.dup
    for (p := parent; p != null; p = p.parent)
      p.vars.each |v, n| { if (acc[n] == null) acc[n] = v }
    return acc
  }

  ** Raw set variable in my scope (no checking)
  Void set(Str name, Obj? val)
  {
    vars[name] = val ?: nullSentinel
  }

  ** Define a new variable.
  ** Return true on success or false if already defined in scope.
  Bool define(Str name, Obj? val)
  {
    if (vars.containsKey(name) && !redefines) return false
    set(name, val)
    return true
  }

  ** Assign to an existing defined variable.
  ** Return true on success or false if not defined in scope.
  Bool assign(Str name, Obj? val)
  {
    if (vars.containsKey(name)) { set(name, val); return true }
    if (parent != null) return parent.assign(name, val)
    return false
  }

  ** Debug string
  override Str toStr() { "AxonScope [vars: $vars.keys]" }

  ** Special value used for null variable values
  internal static const Obj nullSentinel := NullSentinel()

  ** Variables in the scope.  Nulls are stored as nullSentinel.
  private Str:Obj? vars
}

**************************************************************************
** NullSentinel
**************************************************************************

@Js internal const class NullSentinel
{
  override Str toStr() { "null" }
}

