//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** AxonFFI foreign function interface to bind Axon calls to Fantom
**
@Js @NoDoc
abstract const class AxonFFI
{
  ** Static call on type
  abstract Obj? callStatic(AxonContext cx, TopName target, Str name, Expr[] args, AtomicRef cache)

  ** Instance call on this object
  abstract Obj? callDot(AxonContext cx, Obj? target, Str name, Expr[] args)

  ** Field set
  abstract Obj? fieldSet(AxonContext cx, Obj? target, Str name, Expr rhs)
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

  override Obj? callStatic(AxonContext cx, TopName target, Str name, Expr[] args, AtomicRef cache)
  {
    // resolve base type
    type := resolve(target)

    // constructors Foo() use the name <init>; it can be expensive to resolve
    // overloaded constructors, so resolve once then cache for the call site
    if (name == "<init>")
    {
      ctor := cache.val as Method
      if (ctor == null) cache.val = ctor = resolveCtor(cx, type, args)
      return call(cx, ctor, null, args)
    }

    // static field/method
    slot := type.slot(name)
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
    // lookup Fantom slot
    if (target == null) throw NullErr("Dot call on null target: $name")
    slot := target.typeof.slot(name, false)

    // if Fantom slot is null, then try as comp
    if (slot == null)
    {
      // check as comp or fail overall eval
      comp := target as Comp ?: throw UnknownSlotErr("Unknown slot: ${target.typeof}.$name")

      // only get supported right now
      if (args.isEmpty) return comp.get(name)
      throw Err("Invalid args to comp slot: ${target.typeof}.$name")
    }

    // field or method
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

  override Obj? fieldSet(AxonContext cx, Obj? target, Str name, Expr rhs)
  {
    if (target == null) throw NullErr("Field set on null target: $name")

    // lookup Fantom slot
    field := target.typeof.slot(name, false) as Field

    // if Fantom slot is null, then try as comp
    if (field == null)
    {
      // check as comp or fail overall eval
      comp := target as Comp ?: throw UnknownSlotErr("Unknown slot: ${target.typeof}.$name")

      // try to infer type from slot if defined
      slot := comp.spec.slot(name, false)
      type := slot != null ? slot.type.fantomType : Obj#
      val := coerceToFantom(cx, rhs, type)

      // set component slot
      comp.set(name, val)
      return val
    }

    // handle as fantom field
    if (field.isConst) throw Err("Field is const: $field")
    val := coerceToFantom(cx, rhs, field.type)
    field.set(target, val)
    return val
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

//////////////////////////////////////////////////////////////////////////
// Constructor Overrloading
//////////////////////////////////////////////////////////////////////////

  private Method resolveCtor(AxonContext cx, Type type, Expr[] argExprs)
  {
    // eagerly evaluate args
    args := argExprs.map |argExpr, i| { argExpr.eval(cx) }

    // first pass: potential matches on arity without type/coerce checking
    matches := Method[,]
    type.methods.each |m|
    {
      if (m.isCtor && isPotentialCtorMatch(m, args)) matches.add(m)
    }

    // if we found more than one, then filter ones that match based on types
    if (matches.size > 1)
    {
      exacts := matches.findAll |m| { isExactCtorMatch(m, args) }
      if (exacts.size == 1) matches = exacts
    }

    // if we still have multiple, then filter based on coercion
    if (matches.size > 1)
    {
      matches = matches.findAll |m| { isCoerceCtorMatch(cx, m, args) }
    }

    // handle match, no matches, or ambiguous matches
    if (matches.size == 1) return matches.first
    if (matches.size == 0) throw Err("No constructor: " + ctorSig(type, args))
    throw Err("Ambiguous constructor: " + ctorSig(type, args) + " [" + matches.join(",") { it.name } + "]")
  }

  private static Bool isPotentialCtorMatch(Method m, Obj?[] args)
  {
    required := 0
    match := m.params.all |p, i|
    {
      if (!p.hasDefault) required++
      if (i >= args.size) return p.hasDefault
      return true // potential only
    }
    return match && required <= args.size && args.size <= m.params.size
  }

  private static Bool isExactCtorMatch(Method m, Obj?[] args)
  {
    m.params.all |p, i|
    {
      if (i >= args.size) return p.hasDefault
      a := args[i]
      if (a == null) return p.type.isNullable
      return a.typeof.fits(p.type.toNonNullable)
    }
  }

  private static Bool isCoerceCtorMatch(AxonContext cx, Method m, Obj?[] args)
  {
    m.params.all |p, i|
    {
      if (i >= args.size) return p.hasDefault
      a := args[i]
      if (a == null) return p.type.isNullable
      a = coerceToFantomVal(cx, a, p.type)
      return a.typeof.fits(p.type.toNonNullable)
    }
  }

  private static Str ctorSig(Type type, Obj?[] args)
  {
    s := StrBuf().add(type.name).addChar('(')
    args.each |a, i| { if (i > 0) s.add(", "); s.add(a?.typeof?.name) }
    return s.addChar(')').toStr
  }

//////////////////////////////////////////////////////////////////////////
// Coercion
//////////////////////////////////////////////////////////////////////////

  private static Obj? coerceToFantom(AxonContext cx, Expr expr, Type? type)
  {
    // if no Fantom parameter, then no coercion
    if (type == null) return expr.eval(cx)

    // use Fantom type to lazily eval filters
    if (type == Filter#) return expr.evalToFilter(cx)

    // evaluate and coerce the value
    return coerceToFantomVal(cx, expr.eval(cx), type)
  }

  private static Obj? coerceToFantomVal(AxonContext cx, Obj? x, Type type)
  {
    // coerce Fantom Int/Float/Duration -> Number
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

    // if Axon func, make fantom func
    if (x is Fn) return AxonFuncsUtil.toFantomFunc(x, cx)

    // return raw value
    return x
  }

  private static Obj? coerceFromFantom(Obj? x)
  {
    if (x is Num) return Number.makeNum(x)
    if (x is Duration) return Number.makeDuration(x, null)
    return x
  }

  private Type resolve(TopName ref)
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

