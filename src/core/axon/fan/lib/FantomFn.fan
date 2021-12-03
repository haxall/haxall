//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jan 2016  Brian Frank  Creation
//

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
      meta := Etc.emptyDict
      fn := reflectMethod(m, name, meta, null)
      acc[fn.name] = fn
    }
    return acc
  }

  ** Reflect the given method
  static FantomFn? reflectFuncFromType(Type type, Str name, Dict meta, AtomicRef? instanceRef)
  {
    // lookup method by name or _name
    m := type.method("_" + name, false)
    if (m == null) m = type.method(name, false)
    if (m == null) return null

    // route to method
    return reflectMethod(m, name, meta, instanceRef)
  }

  ** Reflect the given method
  static FantomFn reflectMethod(Method m, Str name, Dict meta, AtomicRef? instanceRef)
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
      return LazyFantomFn(name, meta, params, m, instanceRef)
    else
      return FantomFn(name, meta, params, m, instanceRef)
  }

  ** Method to name
  static Str toName(Method m)
  {
    name := m.name
    if (name[0] == '_') name = name[1..-1]
    return name
  }

  internal new make(Str name, Dict meta, FnParam[] params, Method method, AtomicRef? instanceRef)
    : super(Loc(name), name, meta, params, Literal.nullVal)
  {
    this.method       = method
    this.instanceRef  = instanceRef
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Fantom method which backs the function
  const Method method

  ** Instance to call method on if not static
  const AtomicRef? instanceRef

//////////////////////////////////////////////////////////////////////////
// Fn
//////////////////////////////////////////////////////////////////////////

  override Bool isNative() { true }

  override Obj? callx(AxonContext cx, Obj?[] args, Loc callLoc)
  {
    oldCx := Actor.locals[Etc.cxActorLocalsKey]
    Actor.locals.set(Etc.cxActorLocalsKey, cx)

    // security check
    cx.checkCall(this)

    try
      return cx.callInNewFrame(this, args, callLoc)
    catch (EvalErr e)
      throw e
    catch (Err e)
      throw EvalErr("Func failed: $sig; args: ${argsToStr(args)}\n  $e", cx, callLoc, e)
    finally
      Actor.locals[Etc.cxActorLocalsKey] = oldCx
  }

  override Obj? doCall(AxonContext cx, Obj?[] args)
  {
    if (method.isStatic)
      return method.callList(args)
     else
       return method.callOn(instanceRef.val, args)
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
  new make(Str n, Dict d, FnParam[] p, Method m, Obj? i) : super(n, d, p, m, i) {}
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


