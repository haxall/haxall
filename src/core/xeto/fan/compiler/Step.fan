//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2022  Brian Frank  Creation
//  26 Jan 2023  Brian Frank  Repurpose ProtoCompiler
//

using util

**
** Base class for XetoCompiler steps
**
@Js
abstract internal class Step
{
  XetoCompiler? compiler

  abstract Void run()

  XetoEnv env() { compiler.env }

  Bool isLib() { compiler.isLib }

  Bool isData() { !compiler.isLib }

  Str qname() { compiler.qname }

  Bool isSys() { compiler.isSys }

  ASys sys() { compiler.sys }

  AObj ast() { compiler.ast }

  ALib lib() { compiler.lib }

  AObj? pragma() { compiler.pragma }

  Void info(Str msg) { compiler.info(msg) }

  XetoCompilerErr err(Str msg, FileLoc loc, Err? err := null) { compiler.err(msg, loc, err) }

  XetoCompilerErr err2(Str msg, FileLoc loc1, FileLoc loc2, Err? err := null) { compiler.err2(msg, loc1, loc2, err) }

  Void bombIfErr() { if (!compiler.errs.isEmpty) throw compiler.errs.first }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Is given spec the 'sys::Obj' type
  Bool isObj(ASpec x)
  {
    isSys && x.typeRef == null && x.qname == "sys::Obj"
  }

  ** Get meta tag
  AObj? metaGet(AObj obj, Str name)
  {
    if (obj.meta == null) return null
    return obj.meta.slots.get(name)
  }

  ** Return if object has meta tag set and it is not none
  Bool metaHas(AObj obj, Str name)
  {
    x := metaGet(obj, name)
    return x != null && !isNone(x)
  }

  ** Add marker tag to meta
  Void metaAddMarker(AObj obj, Str name)
  {
    metaAdd(obj, name, sys.marker, env.marker)
  }

  ** Add none tag to meta
  Void metaAddNone(AObj obj, Str name)
  {
    dup := metaGet(obj, name)
    if (isNone(dup)) return
    metaAdd(obj, name, sys.none, env.none, "none")
  }

  ** Add none tag to meta
  Void metaAdd(AObj obj, Str name, ARef type, Obj val, Str valStr := val.toStr)
  {
    loc := obj.loc
    kid := obj.metaInit(sys).makeChild(loc, name)
    kid.typeRef = type
    kid.val = AScalar(loc, valStr, val)
    obj.meta.slots.add(kid)
  }

  ** Is object the none scalar value
  Bool isNone(AObj? obj)
  {
    if (obj == null) return false
    if (obj.val == null) return false
    return obj.val.val === env.none
  }

}