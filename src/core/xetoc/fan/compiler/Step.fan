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

  MEnv env() { compiler.env }

  Bool isLib() { compiler.isLib }

  Bool isData() { !compiler.isLib }

  Bool isSys() { compiler.isSys }

  ASys sys() { compiler.sys }

  ANode ast() { compiler.ast }

  ALib lib() { compiler.lib }

  ADict? pragma() { compiler.pragma }

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

// TODO: move this into ASpec for cleaner API

  ** Add marker tag to meta
  Void metaAddMarker(ASpec obj, Str name)
  {
    metaAdd(obj, name, sys.marker, env.marker)
  }

  ** Add none tag to meta
  Void metaAddNone(ASpec obj, Str name)
  {
    metaAdd(obj, name, sys.none, env.none, "none")
  }

  ** Add none tag to meta
  Void metaAdd(ASpec obj, Str name, ASpecRef type, Obj val, Str valStr := val.toStr)
  {
//     loc := obj.loc
//     kid := obj.metaInit.makeChild(loc, name)
//     kid.typeRef = type
//     kid.val = AScalar(loc, valStr, val)
//     obj.meta.slots.add(kid)
throw Err("META ADD $name $type $val")
  }

  ** Is object the none scalar value
  Bool isNone(AData? obj)
  {
    if (obj == null) return false
    scalar := obj as AScalar
    if (scalar == null) return false
    return scalar.asmRef === env.none
  }

}




