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

  ** Return a const copy with a snapshot of the variables in the
  ** captured scope; variables which cannot be immutable raise an
  ** error if used
  override ConstClosure toConst()
  {
    ConstClosure(lambda, scope?.toConstVars ?: Str:Obj[:])
  }

  ** Debug string
  override Str toStr() { lambda.toStr }
}

**************************************************************************
** ConstClosure
**************************************************************************

**
** ConstClosure is a lambda paired with an immutable snapshot of the
** variables it captured.  Each call runs the lambda in a new scope
** nested in the snapshot; captured variables cannot be assigned.
**
@NoDoc @Js
const class ConstClosure : Callable
{
  ** Constructor
  internal new make(Lambda lambda, Str:Obj vars)
  {
    this.lambda = lambda
    this.vars   = vars
  }

  ** Lambda definition
  const Lambda lambda

  ** Snapshot of captured variables
  internal const Str:Obj vars

  ** Lambda name
  override Str name() { lambda.name }

  ** Lambda parameters
  override FnParam[] params() { lambda.params }

  ** Lambda number of parameters
  override Int arity() { lambda.arity }

  ** Lambdas are never lazy
  override Bool isLazy() { false }

  ** Call the lambda in a new scope nested in the snapshot
  override Obj? call(AxonContext cx, Obj?[] args, FileLoc callLoc := FileLoc.unknown)
  {
    lambda.callNested(cx, args, callLoc, vars.isEmpty ? null : AxonScope.makeConst(vars))
  }

  ** Return this
  override Callable toConst() { this }

  ** Debug string
  override Str toStr() { lambda.toStr }
}

