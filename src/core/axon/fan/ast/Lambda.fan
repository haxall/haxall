//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2026  Brian Frank  Creation
//

using util

**
** Lambda is an anonymous function expression such as '(x) => x + 1'.
** It evaluates to a Closure over the current scope.
**
@NoDoc @Js
const class Lambda : Fn
{
  @NoDoc new make(FileLoc loc, Str name, FnParam[] params, Expr body)
    : super(loc, name, params, body)
  {
  }

  ** Evaluate to a closure over the current scope
  override Obj? eval(AxonContext cx) { Closure(this, cx.curScope(false)) }
}

**************************************************************************
** Closure
**************************************************************************

**
** Closure is a lambda paired with the scope it was evaluated in.
** Each call runs the lambda in a new scope nested in that scope,
** so it resolves names where it was defined, not where it is called.
**
@NoDoc @Js
class Closure : Callable
{
  ** Constructor
  new make(Lambda lambda, AxonScope? scope)
  {
    this.lambda = lambda
    this.scope  = scope
  }

  ** Lambda definition
  const Lambda lambda

  ** Scope the lambda was evaluated in
  AxonScope? scope { private set }

  ** Lambda name
  override Str name() { lambda.name }

  ** Lambda parameters
  override FnParam[] params() { lambda.params }

  ** Lambda number of parameters
  override Int arity() { lambda.arity }

  ** Lambdas are never lazy
  override Bool isLazy() { false }

  ** Call the lambda in a new scope nested in the captured scope
  override Obj? call(AxonContext cx, Obj?[] args, FileLoc callLoc := FileLoc.unknown)
  {
    lambda.callNested(cx, args, callLoc, scope)
  }

  ** Debug string
  override Str toStr() { lambda.toStr }
}

