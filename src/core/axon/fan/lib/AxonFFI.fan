//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using concurrent

**
** AxonFFI foreign function interface to bind Axon calls to Fantom
**
@Js @NoDoc
abstract const class AxonFFI
{
  ** Static call on type
  abstract Obj? callStatic(AxonContext cx, TypeRef type, Str name, Obj?[] args)

  ** Instance call on this object
  abstract Obj? callDot(AxonContext cx, Obj? target, Str name, Obj?[] args)
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

  override Obj? callStatic(AxonContext cx, TypeRef type, Str name, Obj?[] args)
  {
    slot := resolve(type).slot(name)
    if (slot.isField)
    {
      return ((Field)slot).get(null)
    }
    else
    {
      return ((Method)slot).callOn(null, args)
    }
  }

  override Obj? callDot(AxonContext cx, Obj? target, Str name, Obj?[] args)
  {
    if (target == null) throw NullErr("Dot call on null target: $name")
    slot := target.typeof.slot(name)
    if (slot.isField)
    {
      if (args.isEmpty)
        return ((Field)slot).get(target)
      else
        throw Err("Invalid args to field set: $slot")
    }
    else
    {
      return ((Method)slot).callOn(target, args)
    }
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

