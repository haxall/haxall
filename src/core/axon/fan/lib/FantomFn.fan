//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jan 2016  Brian Frank  Creation
//

using xeto
using haystack
using concurrent

**
** FantomFn is an Axon function backed by a Fantom method
**
@Js @NoDoc
const class FantomFn : TopFn
{

//////////////////////////////////////////////////////////////////////////
// Reflect
//////////////////////////////////////////////////////////////////////////

  ** Reflect all the methods from a given type annotated with Axon facet
  static Str:FantomFn reflectType(Type type)
  {
    acc := Str:FantomFn[:]
    type.methods.each |m|
    {
      if (!m.isPublic) return
      if (m.parent !== type) return
      facet := m.facet(Axon#, false)
      if (facet == null) return
      name := FantomFn.toName(m)
      meta := Etc.dict0
      fn := reflectMethod(m, name, meta)
      acc[fn.name] = fn
    }
    return acc
  }

  ** Reflect the given method
  static FantomFn? reflectFuncFromType(Type type, Str name, Dict meta)
  {
    // lookup method by name or _name
    m := type.method("_" + name, false)
    if (m == null) m = type.method(name, false)
    if (m == null) return null

    // route to method
    return reflectMethod(m, name, meta)
  }

  ** Reflect the given method
  static FantomFn reflectMethod(Method m, Str name, Dict meta)
  {
    // map Param[] to FnParam[] name, and check if arg
    // requires an un-evaluated Expr (lazy func)
    lazy := false
    params := m.params.map |Param p->FnParam|
    {
      if (!Etc.isTagName(p.name)) throw Err("Invalid func param name: $p")
      if (p.type === Expr#) lazy = true
      if (p.type.fits(Func#)) echo("WARNING AXON FUNC ARG: $m")
      return FnParam.makeFan(p)
    }

    if (lazy)
      return LazyFantomFn(name, meta, params, m)
    else
      return FantomFn(name, meta, params, m)
  }

  ** Method to name
  static Str toName(Method m)
  {
    name := m.name
    if (name[0] == '_') name = name[1..-1]
    return name
  }

  protected new make(Str name, Dict meta, FnParam[] params, Method method)
    : super(Loc(name), name, meta, params, Literal.nullVal)
  {
    if (!method.isStatic) throw Err("Method not static: $method")
    this.method = method
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Fantom method which backs the function
  const Method method

//////////////////////////////////////////////////////////////////////////
// Fn
//////////////////////////////////////////////////////////////////////////

  override Bool isNative() { true }

  override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    oldCx := AxonContext.curAxon(false)
    setCx := cx !== oldCx
    if (setCx) Actor.locals.set(AxonContext.actorLocalsKey, cx)

    // security check
    cx.checkCall(this)

    try
      return cx.callInNewFrame(this, args, callLoc)
    catch (EvalErr e)
      throw e
    catch (Err e)
      throw EvalErr("Func failed: $sig; args: ${argsToStr(args)}\n  $e", cx, callLoc, e)
    finally
      if (setCx)
      {
        if (oldCx == null)
          Actor.locals.remove(AxonContext.actorLocalsKey)
        else
          Actor.locals.set(AxonContext.actorLocalsKey, oldCx)
      }
  }

  override Obj? doCall(AxonContext cx, Obj?[] args)
  {
    return method.callList(args)
  }

  override Obj? evalParamDef(AxonContext cx, FnParam param)
  {
    p := method.params.find |x| { x.name == param.name } ?: throw Err("Invalid param: $param.name")
    return method.paramDef(p, null)
  }

  override Str sig()
  {
    name + "(" + method.params.join(",") |p| { "$p.type.name $p.name" } + ")"
  }

  Str argsToStr(Obj?[] args)
  {
    "(" + args.join(",") |arg| { arg == null ? "null" : arg.typeof.name } + ")"
  }

}

**************************************************************************
** LazyFantomFn
**************************************************************************

**
** LazyFantomFn calls the method with the expr before it is evaluated.
**
@Js @NoDoc
internal const class LazyFantomFn : FantomFn
{
  new make(Str n, Dict d, FnParam[] p, Method m) : super(n, d, p, m) {}

  override Bool isLazy() { true }

  override Obj? callLazy(AxonContext cx, Expr[] args, Loc callLoc)
  {
    super.callx(cx, args, callLoc)
  }
}

**************************************************************************
** FantomClosureFn
**************************************************************************

**
** Wrap an mutable Fantom function as an Axon function expression.
**
@NoDoc
const class FantomClosureFn : Fn
{
  new make(Func f) : super(Loc("Fantom Func"), "fan", FnParam.makeFanList(f))
  {
    this.f = Unsafe(f)
  }

  override Bool isNative() { true}

  override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    ((Func)f.val).callList(args)
  }

  const Unsafe f
}

**************************************************************************
** FilterFn
**************************************************************************

@Js
internal const class FilterFn : Fn
{
  new make(Filter filter) : super(Loc.unknown, "filterToFunc", [FnParam("dict")])
  {
    this.filter = filter
  }

  const Filter filter

  override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    dict := args.first as Dict
    if (dict == null) throw err("Invalid arg, expected (Dict) not (${args.first?.typeof})", cx)
    return filter.matches(dict, cx)
  }
}

