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

  Bool isNone(AObj? obj)
  {
    if (obj == null) return false
    if (obj.val == null) return false
    return obj.val.val === env.none
  }
}