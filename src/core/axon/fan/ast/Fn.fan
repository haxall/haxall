//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Sep 2009  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** Fn is a function definition
**
@Js
const class Fn : Expr, HaystackFunc
{
  @NoDoc new make(Loc loc, Str name, FnParam[] params, Expr body := Literal.nullVal)
  {
    this.loc    = loc
    this.name   = name
    this.params = params
    this.body   = body
  }

  @NoDoc override ExprType type() { ExprType.func }

  @NoDoc override const Loc loc

  ** Top-level name or debug name if closure
  const Str name

  virtual Dict meta() { Etc.dict0 }

  virtual Bool isTop() { false }

  ** Parent lexically scoped function
  @NoDoc Fn? outer() { outerRef.val }
  internal const AtomicRef outerRef := AtomicRef(null)

  @NoDoc const FnParam[] params

  @NoDoc Int arity() { params.size }

  @NoDoc Int requiredArity()
  {
    i := 0
    for (; i<params.size; ++i)
      if (!params[i].hasDef) break
    return i
  }

  @NoDoc const Expr body

  ** Return this
  override Obj? eval(AxonContext cx) { this }

  ** Return if this function is a component
  @NoDoc virtual Bool isComp() { false }

  ** Return if this method is implemented in Fantom
  @NoDoc virtual Bool isNative() { false }

  ** Return if this function requires superuser permission
  @NoDoc virtual Bool isSu() { false }

  ** Return if this function requires admin permission
  @NoDoc virtual Bool isAdmin() { false }

  ** Return if this function has been deprecated
  @NoDoc virtual Bool isDeprecated() { false }

  ** Invoke this function with the given arguments.
  ** Note: the 'args' parameter must be mutable and may be modified
  Obj? call(AxonContext cx, Obj?[] args) { callx(cx, args, Loc.unknown) }

  @NoDoc final override Obj? haystackCall(HaystackContext cx, Obj?[] args)
  {
    call(cx, args)
  }

  @NoDoc virtual Obj? callLazy(AxonContext cx, Expr[] args, Loc callLoc)
  {
    callx(cx, args.map |arg| { arg.eval(cx) }, callLoc)
  }

  @NoDoc virtual Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    // call heartbeat to check for interruption
    cx.heartbeat(callLoc)

    // check arity
    if (arity != args.size)
    {
      args = args.rw
      while (args.size < params.size)
      {
        def := params[args.size].def
        if (def == null) break
        args.add(def.eval(cx))
      }

      if (args.size < params.size)
        throw err("Invalid number of args $args.size, expected $arity", cx)
    }

    // evaluate function body with nested scope
    return cx.callInNewFrame(this, args, callLoc)
  }

  @NoDoc virtual Obj? doCall(AxonContext cx, Obj?[] args)
  {
    Obj? result := null
    try
      result = body.eval(cx)
    catch (ReturnErr e)
      result = ReturnErr.getVal
    if (result is Grid) ((Grid)result).first // force lazy load grids
    return result
  }

  @NoDoc virtual Obj? evalParamDef(AxonContext cx, FnParam param)
  {
    if (param.def == null) throw Err("Param has no def: $param.name")
    return param.def.eval(cx)
  }

  @NoDoc virtual Str sig() { name + "(" + params.join(",") + ")" }

  override Void walk(|Str key, Obj? val| f)
  {
    f("params", params)
    f("body", body)
  }

  ** Print
  @NoDoc override Printer print(Printer out)
  {
    out.atomicStart.wc('(')
    params.each |p, i|
    {
      if (i > 0) out.comma
      p.print(out)
    }
    out.w(") => ")
    body.print(out)
    return out.atomicEnd
  }
}

**************************************************************************
** TopFn
**************************************************************************

**
** Top level function in the namespace
**
@Js
const class TopFn : Fn, Thunk
{
  new make(Loc loc, Str name, Dict meta, FnParam[] params, Expr body := Literal.nullVal)
    : super(loc, name, params, body)
  {
    this.meta = meta
    this.isSu         = meta.has("su")
    this.isAdmin      = this.isSu || meta.has("admin")
    this.isDeprecated = meta.has("deprecated")
  }

  ** Func def metadata
  override const Dict meta

  ** Return true
  override Bool isTop() { true }

  ** Is this function tagged as admin-only
  const override Bool isAdmin

  ** Is this function tagged as superuser-only
  const override Bool isSu

  ** Return if this function has been deprecated
  const override Bool isDeprecated

  ** Is this a lazy function that accepts un-evaluated arguments
  virtual Bool isLazy() { false }

  ** Return only name
  override Str toStr() { name }

  ** Thunk.call implementation
  override Obj? callList(Obj?[]? args := null)
  {
    call(AxonContext.curAxon, args ?: noArgs)
  }

  ** Add check call
  @NoDoc override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    cx.checkCall(this)
    return super.callx(cx, args, callLoc)
  }

  internal static const Obj?[] noArgs := Obj?[,]
}

**************************************************************************
** FnParam
**************************************************************************

**
** Function parameter
**
@NoDoc
@Js
const class FnParam
{
  static FnParam[] makeNum(Int num) { byNum[num] }

  static const FnParam[] cells := [make("cells")]

  static FnParam[] makeFanList(Func f)
  {
    f.params.map |p->FnParam| { makeFan(p) }
  }

  new makeFan(Param p)
  {
    this.name   = p.name
    this.hasDef = p.hasDefault
  }

  private static const FnParam[][] byNum
  static
  {
    acc := FnParam[][,]
    20.times |num|
    {
      params := FnParam[,]
      num.times |i| { params.add(FnParam(('a'+i).toChar)) }
      acc.add(params.toImmutable)
    }
    byNum = acc
  }

  new make(Str name, Expr? def := null)
  {
    this.name   = name
    this.def    = def
    this.hasDef = def != null
  }

  const Str name

  const Expr? def

  const Bool hasDef

  Dict encode()
  {
    def == null ? Etc.dict1("name", name) : Etc.dict2("name", name, "def", def.encode)
  }

  Void print(Printer out)
  {
    out.w(name)
    if (def != null) out.wc(':').expr(def)
  }

  override Str toStr() { def == null ? name : "$name: $def" }
}

**************************************************************************
** ReturnErr
**************************************************************************

**
** Used by ReturnExpr to implement return flow control.
** Result is stuck into local variable since Expr/Err are const.
** Note: simple but not very efficient way to handle control flow
**
@Js
internal const class ReturnErr : Err
{
  new make() : super("") {}
  static Obj? getVal() { Actor.locals.remove("axon.returnVal") }
  static Void putVal(Obj? v) { Actor.locals["axon.returnVal"] = v }
}

