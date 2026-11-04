//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Oct 2009  Brian Frank  Creation
//   3 Nov 2026  Brian Frank  Split out from CallFrame
//

using util
using xeto
using haystack

**
** AxonFrame manages call stack and pushing new scopes
**
@NoDoc @Js
abstract class AxonFrame
{
  ** Create new frame with given variable scope
  internal new make(AxonScope scope) { this.scope = scope }

  ** Variable scope
  AxonScope scope { private set }

  ** Run the frame
  internal abstract Obj? run(AxonContext cx)

  ** Function is call frame
  internal abstract Fn? func()

  ** Debug string
  override Str toStr() { "$typeof.name $func" }

}

**************************************************************************
** EvalFrame
**************************************************************************

**
** EvalFrame is used to evaluate an expression when run
**
@Js
internal final class EvalFrame : AxonFrame
{
  new make(AxonScope scope, Expr expr) : super(scope)
  {
    this.expr = expr
  }

  override Obj? run(AxonContext cx) { expr.eval(cx) }

  override Fn? func() { null }

  const Expr expr
}

**************************************************************************
** CallFrame
**************************************************************************

**
** CallFrame is used to call a function when run
**
@Js
internal final class CallFrame : AxonFrame
{
  new make(AxonScope scope, Fn func, Obj?[] args, FileLoc callLoc) : super(scope)
  {
    this.func    = func
    this.callLoc = callLoc
    this.args    = args

   // TODO - revisit this
   // bind parameter variables to arguments
    if (!func.isNative)
      func.params.each |param, i| { scope.set(param.name, args[i]) }
  }

  override Obj? run(AxonContext cx) { func.doCall(cx, args)  }

  override const Fn? func

  const FileLoc callLoc
  private Obj?[] args
}

**************************************************************************
** CaptureFrame (TODO)
**************************************************************************

**
** CaptureFrame calls a function in a lexical scope captured by
** AxonContext.scopeCapture.  It stands in for the function's lexically
** enclosing frame so scopeParent resolves to the captured scope.
**
@Js
internal final class CaptureFrame : AxonFrame
{
  new make(AxonScope scope, Fn fn, Obj?[] args, FileLoc callLoc) : super(scope)
  {
    this.fn      = fn
    this.callLoc = callLoc
    this.args    = args
  }

  override Obj? run(AxonContext cx) { fn.callx(cx, args, callLoc) }

  override Fn? func() { fn.outer }

  const Fn fn
  const FileLoc callLoc
  private Obj?[] args
}

