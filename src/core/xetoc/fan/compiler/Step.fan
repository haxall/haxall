//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2022  Brian Frank  Creation
//  26 Jan 2023  Brian Frank  Repurpose ProtoCompiler
//

using util
using xeto
using xetom

**
** Base class for XetoCompiler steps
**
@Js
abstract internal class Step
{
  MXetoCompiler? compiler

  abstract Void run()

  MNamespace? ns() { compiler.ns }

  ANamespace cns() { compiler.cns }

  CompileMode mode() { compiler.mode }

  Bool isLib() { compiler.mode.isLib }

  Bool isData() { compiler.mode.isData }

  Bool isSys() { compiler.isSys }

  Bool isSysComp() { compiler.isSysComp }

  Bool isCompanion() { compiler.isCompanion }

  ASys sys() { compiler.sys }

  ADepends depends() { compiler.depends }

  ADoc ast() { compiler.ast }

  ADataDoc data() { compiler.data }

  ALib lib() { compiler.lib }

  ADict? pragma() { compiler.pragma }

  SpecMap metas() { compiler.metas }

  Void info(Str msg) { compiler.info(msg) }

  XetoCompilerErr err(Str msg, FileLoc loc, Err? err := null) { compiler.err(msg, loc, err) }

  XetoCompilerErr errSlot(Spec? slot, Str msg, FileLoc loc, Err? err := null) { compiler.errSlot(slot, msg, loc, err) }

  XetoCompilerErr err2(Str msg, FileLoc loc1, FileLoc loc2, Err? err := null) { compiler.err2(msg, loc1, loc2, err) }

  Void bombIfErr() { if (!compiler.errs.isEmpty) throw compiler.errs.first }

  Bool isObj(Spec s) { s.base == null }

  AScalar strScalar(FileLoc loc, Str str)
  {
    AScalar(loc, sys.str, str, str)
  }

  File[] dirList(File dir)
  {
    // use consistent ordering
    dir.list.sort |a, b| { a.name <=> b.name }
  }

  Bool metaHas(Spec x, Str n)
  {
    x is ASpec ? ((ASpec)x).metaHas(n) : x.meta.has(n)
  }

  MSpecArgs specToArgs(Spec x)
  {
    x is ASpec ? ((ASpec)x).args : ((XetoSpec)x).args
  }
}

