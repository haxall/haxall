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
  ** Create new scope with no varaibles
  new make0()
  {
    this.vars = Str:Obj?[:]
  }

  ** Create new scope with
  new make(Str n0, Obj? v0)
  {
    this.vars = Str:Obj?[n0: v0 ?: nullSentinel]
  }

  ** Create new scope with one variable
  new make1(Str n0, Obj? v0, Str n1, Obj? v1)
  {
    this.vars = Str:Obj?[n0: v0 ?: nullSentinel, n1: v1 ?: nullSentinel]
  }

  ** Create new scope with given map
  internal new makeMap(Str:Obj? vars)
  {
    this.vars = vars.map |v| { v == null ? nullSentinel : v }
  }

  ** Create new scope with given lexical scope parent and initial variables
  internal new makeNested(AxonScope? parent, Str:Obj? vars)
  {
    this.parent = parent
    this.vars   = vars.map |v| { v == null ? nullSentinel : v }
  }

  ** Flag to allow re-defines such in a REPL
  Bool redefines

  ** Parent scope in the chain or null if this is root scope
  AxonScope? parent { private set }

  ** Return if given variable name is defined in the scope chain
  Bool has(Str name)
  {
    if (vars.containsKey(name)) return true
    if (parent != null) return parent.has(name)
    return false
  }

  ** Get variable in the scope chain or null if not found
  Obj? get(Str name)
  {
    v := vars.get(name)
    if (v != null) return v === nullSentinel ? null : v
    return parent?.get(name)
  }

  ** Get variable in scope or resolve to top name
  Obj? resolve(AxonContext cx, Str name, FileLoc loc)
  {
    // resolve in my scope
    v := vars.get(name)
    if (v != null) return v === nullSentinel ? null : v

    // recurse to parent scope if applicable
    if (parent != null) return parent.resolve(cx, name, loc)

    // resolve as unqualified top-level name
    return TopName(loc, null, name).eval(cx)
  }

  ** Return effective map of all variables in scope
  Str:Obj? effective()
  {
    acc := vars.dup
    for (p := parent; p != null; p = p.parent)
      p.vars.each |v, n| { if (acc[n] == null) acc[n] = v }
    return acc.map |v->Obj?| { v === nullSentinel ? null : v }
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

  private static const Str nullSentinel := "__null__"

  private Str:Obj? vars
}

