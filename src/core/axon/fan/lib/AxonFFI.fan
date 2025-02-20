//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using concurrent
using haystack

**
** AxonFFI foreign function interface to bind Axon calls to Fantom
**
@Js @NoDoc
abstract const class AxonFFI
{
  ** Static call on type
  abstract Obj? callStatic(AxonContext cx, TypeRef type, Str name, Expr[] args)

  ** Instance call on this object
  abstract Obj? callDot(AxonContext cx, Obj? target, Str name, Expr[] args)
}

**************************************************************************
** FantomAxonFFI
**************************************************************************

@Js @NoDoc
const class FantomAxonFFI : AxonFFI
{
  new make(Pod[] pods)
  {
    this.pods = pods
    this.types = ConcurrentMap()
  }

  override Obj? callStatic(AxonContext cx, TypeRef type, Str name, Expr[] args)
  {
    slot := resolve(type).slot(name)
    if (slot.isField)
    {
      return get(slot, null)
    }
    else
    {
      return call(cx, slot, null, args)
    }
  }

  override Obj? callDot(AxonContext cx, Obj? target, Str name, Expr[] args)
  {
    if (target == null) throw NullErr("Dot call on null target: $name")
    slot := target.typeof.slot(name)
    if (slot.isField)
    {
      if (args.isEmpty)
        return get(slot, target)
      else
        throw Err("Invalid args to field set: $slot")
    }
    else
    {
      return call(cx, slot, target, args)
    }
  }

  private Obj? get(Field f, Obj? target)
  {
    coerceFromFantom(f.get(target))
  }

  private Obj? call(AxonContext cx, Method m, Obj? target, Expr[] argExprs)
  {
    params := m.params
    args := argExprs.map |argExpr, i|
    {
      coerceToFantom(cx, argExpr, params.getSafe(i)?.type)
    }

    return coerceFromFantom(m.callOn(target, args))
  }

  private Obj? coerceToFantom(AxonContext cx, Expr expr, Type? type)
  {
    // use Fantom type to lazily eval filters
    if (type == Filter#) return expr.evalToFilter(cx)

    x := expr.eval(cx)

    if (type == Int#)
    {
      if (x is Number) return ((Number)x).toInt
      return x
    }

    if (type == Float#)
    {
      if (x is Number) return ((Number)x).toFloat
      return x
    }

    if (type == Duration#)
    {
      if (x is Number) return ((Number)x).toDuration
      return x
    }

    return x
  }

  private Obj? coerceFromFantom(Obj? x)
  {
    if (x is Num) return Number.makeNum(x)
    if (x is Duration) return Number.makeDuration(x, null)
    return x
  }

  private Type resolve(TypeRef ref)
  {
    name := ref.name

    // non-qualified
    if (ref.lib == null)
    {
      t := types[name]
      if (t != null) return t

      t = doResolve(name)
      if (t != null)
      {
        types[name] = t
        return t
      }

      throw UnknownTypeErr(name)
    }

    // qualified
    else
    {
      pod := podsByName[ref.lib] ?: throw UnknownTypeErr("${ref.lib}::${name}")
      return pod.type(name)
    }
  }

  private Type? doResolve(Str name)
  {
    Type? match := null
    pods.each |pod|
    {
      t := pod.type(name, false)
      if (t == null) return
      if (match != null) throw UnresolvedErr("Ambiguous type name: $match, $t")
      match = t
    }
    return match
  }

  private once Str:Pod podsByName()
  {
    Str:Pod[:].setList(pods) { it.name }.toImmutable
  }

  private const Pod[] pods            // namespace of pods to import
  private const ConcurrentMap types   // resolved unqualified type names
}

