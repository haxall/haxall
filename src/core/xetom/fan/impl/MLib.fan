//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** Implementation of Lib wrapped by XetoLib
**
@Js
const final class MLib
{
  new make(FileLoc loc, Str name, Dict meta, Int flags, Version version, MLibDepend[] depends, Str:Spec specsMap, Str:Dict instancesMap, MLibFiles files)
  {
    this.loc          = loc
    this.name         = name
    this.id           = Ref(StrBuf(4+name.size).add("lib:").add(name).toStr, null)
    this.isSys        = name == "sys"
    this.meta         = meta
    this.flags        = flags
    this.version      = version
    this.depends      = depends
    this.specsMap     = specsMap
    this.instancesMap = instancesMap
    this.files        = files
  }

  const FileLoc loc

  const Ref id

  const Str name

  const Bool isSys

  const Dict meta

  const Version version

  const LibDepend[] depends

  const Str:Spec specsMap

  const Str:Dict instancesMap

  const MLibFiles files

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
    specs.findAll |x| { x.isType && x.name[0] != '_' }.toImmutable
  }

  Spec? type(Str name, Bool checked := true)
  {
    top := spec(name, checked)
    if (top != null && top.isType) return top
    if (checked) throw UnknownSpecErr(this.name + "::" + name)
    return null
  }

  once Spec[] mixins()
  {
    specs.findAll |x| { x.isMixin }.toImmutable
  }

  Spec? mixinFor(Spec type, Bool checked := true)
  {
    x := specsMap[type.name]
    if (x != null && x.isMixin && x.base === type) return x
    if (checked) throw UnknownSpecErr("No mixin for $type.qname")
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
    if (checked) throw UnknownRecErr(this.name + "::" + name)
    return null
  }

  Void eachInstance(|Dict| f)
  {
    instancesMap.each(f)
  }

  override Str toStr() { name }

//////////////////////////////////////////////////////////////////////////
// Dict Representation
//////////////////////////////////////////////////////////////////////////

  const static Ref libSpecRef := Ref("sys::Lib")

  Obj? get(Str name)
  {
    if (name == "id")     return id
    if (name == "spec")   return libSpecRef
    if (name == "loaded") return Marker.val
    return meta.get(name)
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
    f(id,         "id")
    f(libSpecRef, "spec")
    f(Marker.val, "loaded")
    meta.each(f)
  }

  Obj? eachWhile(|Obj val, Str name->Obj?| f)
  {
    r := f(id, "id");             if (r != null) return r
    r  = f(libSpecRef, "spec");   if (r != null) return r
    r  = f(Marker.val, "loaded"); if (r != null) return r
    return meta.eachWhile(f)
  }

  override Obj? trap(Str name, Obj?[]? args := null)
  {
    val := get(name)
    if (val != null) return val
    return meta.trap(name, args)
  }

  Bool hasFlag(Int flag) { flags.and(flag) != 0 }

  const Int flags

}

**************************************************************************
** MLibFlags
**************************************************************************

@Js
const class MLibFlags
{
  static const Int hasMarkdown := 0x0001

  static Str flagsToStr(Int flags)
  {
    s := StrBuf()
    MLibFlags#.fields.each |f|
    {
      if (f.isStatic && f.type == Int#)
      {
        has := flags.and(f.get(null)) != 0
        if (has) s.join(f.name, ",")
      }
    }
    return "{" + s.toStr + "}"
  }
}

**************************************************************************
** XetoLib
**************************************************************************

**
** XetoLib is the referential proxy for MLib
**
@Js
const final class XetoLib : Lib, Dict
{
  override FileLoc loc() { m.loc }

  override Ref id() { m.id }

  override Str name() { m.name }

  override Dict meta() { m.meta }

  override Version version() { m.version }

  override LibDepend[] depends() { m.depends }

  override Spec[] specs() { m.specs }

  override Spec? spec(Str name, Bool checked := true) { m.spec(name, checked) }

  override Spec[] types() { m.types }

  override Spec? type(Str name, Bool checked := true) { m.type(name, checked) }

  override Spec[] mixins() { m.mixins }

  override Spec? mixinFor(Spec type, Bool checked := true) { m.mixinFor(type, checked) }

  override Dict[] instances() { m.instances }

  override Dict? instance(Str name, Bool checked := true) { m.instance(name, checked) }

  override Void eachInstance(|Dict| f) { m.eachInstance(f) }

  override Bool isSys() { m.isSys }

  override Bool hasMarkdown() { m.hasFlag(MLibFlags.hasMarkdown )}

  override LibFiles files() { m.files }

  override final Bool isEmpty() { false }

  @Operator override final Obj? get(Str n) { m.get(n) }

  override final Bool has(Str n) { m.has(n) }

  override final Bool missing(Str n) { m.missing(n) }

  override final Void each(|Obj val, Str name| f) { m.each(f) }

  override final Obj? eachWhile(|Obj,Str->Obj?| f) { m.eachWhile(f) }

  override final Obj? trap(Str n, Obj?[]? a := null) { m.trap(n, a) }

  override Str toStr() { "$name-$version" }

  const MLib? m
}

