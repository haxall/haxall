//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::UnknownSpecErr

**
** Implementation of Lib wrapped by XetoLib
**
@Js
const final class MLib
{
  new make(MEnv env, FileLoc loc, Int nameCode, MNameDict meta, Version version, MLibDepend[] depends, Str:Spec specsMap, Str:Dict instancesMap)
  {
    this.env          = env
    this.loc          = loc
    this.nameCode     = nameCode
    this.name         = env.names.toName(nameCode)
    this.id           = haystack::Ref(StrBuf(4+name.size).add("lib:").add(name).toStr, null)
    this.meta         = meta
    this.version      = version
    this.depends      = depends
    this.specsMap     = specsMap
    this.instancesMap = instancesMap
  }

  const MEnv env

  const FileLoc loc

  const Ref id

  const Int nameCode

  const Str name

  const MNameDict meta

  const Version version

  const LibDepend[] depends

  const Str:Spec specsMap

  const Str:Dict instancesMap

  once Spec[] specs()
  {
    if (specsMap.isEmpty)
      return Spec#.emptyList
    else
      return specsMap.vals.sort |a, b| { a.name <=> b.name }.toImmutable
  }

  Spec? spec(Str name, Bool checked := true)
  {
    x := specsMap[name]
    if (x != null) return x
    if (checked) throw UnknownSpecErr(this.name + "::" + name)
    return null
  }

  once Spec[] types()
  {
    specs.findAll |x| { x.isType }.toImmutable
  }

  Spec? type(Str name, Bool checked := true)
  {
    top := spec(name, checked)
    if (top != null && top.isType) return top
    if (checked) throw UnknownSpecErr(this.name + "::" + name)
    return null
  }

  once Spec[] globals()
  {
    specs.findAll |x| { x.isGlobal }.toImmutable
  }

  Spec? global(Str name, Bool checked := true)
  {
    top := spec(name, checked)
    if (top != null && top.isGlobal) return top
    if (checked) throw UnknownSpecErr(this.name + "::" + name)
    return null
  }

  once Dict[] instances()
  {
    if (instancesMap.isEmpty)
      return Dict#.emptyList
    else
      return instancesMap.vals.sort |a, b| { a->id <=> b->id }.toImmutable
  }

  Dict? instance(Str name, Bool checked := true)
  {
    instance := instancesMap[name]
    if (instance != null) return instance
    if (checked) throw haystack::UnknownRecErr(this.name + "::" + name)
    return null
  }

  override Str toStr() { name }

//////////////////////////////////////////////////////////////////////////
// Dict Representation
//////////////////////////////////////////////////////////////////////////

  Obj? get(Str name, Obj? def := null)
  {
    if (name == "id")     return id
    if (name == "spec")   return env.libSpecRef
    if (name == "loaded") return env.marker
    return meta.get(name, def)
  }

  Bool has(Str name)
  {
    if (name == "id")     return true
    if (name == "spec")   return true
    if (name == "loaded") return true
    return meta.has(name)
  }

  Bool missing(Str name)
  {
    if (name == "id")     return false
    if (name == "spec")   return false
    if (name == "loaded") return false
    return meta.missing(name)
  }

  Void each(|Obj val, Str name| f)
  {
    f(id,             "id")
    f(env.libSpecRef, "spec")
    f(env.marker,     "loaded")
    meta.each(f)
  }

  Obj? eachWhile(|Obj val, Str name->Obj?| f)
  {
    r := f(id, "id");               if (r != null) return r
    r  = f(env.libSpecRef, "spec"); if (r != null) return r
    r  = f(env.marker, "loaded");   if (r != null) return r
    return meta.eachWhile(f)
  }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    val := get(name, null)
    if (val != null) return val
    return meta.trap(name, args)
  }

}

**************************************************************************
** XetoLib
**************************************************************************

**
** XetoLib is the referential proxy for MLib
**
@Js
const final class XetoLib : Lib, haystack::Dict
{
  override FileLoc loc() { m.loc }

  XetoEnv env() { m.env }

  override haystack::Ref id() { m.id }

  override haystack::Ref _id() { m.id }

  override Str name() { m.name }

  override Dict meta() { m.meta }

  override Version version() { m.version }

  override LibDepend[] depends() { m.depends }

  override Spec[] specs() { m.specs }

  override Spec? spec(Str name, Bool checked := true) { m.spec(name, checked) }

  override Spec[] types() { m.types }

  override Spec? type(Str name, Bool checked := true) { m.type(name, checked) }

  override Spec[] globals() { m.globals }

  override Spec? global(Str name, Bool checked := true) { m.global(name, checked) }

  override Dict[] instances() { m.instances }

  override Dict? instance(Str name, Bool checked := true) { m.instance(name, checked) }

  override final Bool isEmpty() { false }

  @Operator override final Obj? get(Str n, Obj? d := null) { m.get(n, d) }

  override final Bool has(Str n) { m.has(n) }

  override final Bool missing(Str n) { m.missing(n) }

  override final Void each(|Obj val, Str name| f) { m.each(f) }

  override final Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override final Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

  const MLib? m
}

