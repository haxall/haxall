//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Base class for DocCompiler steps
**
abstract internal class Step
{
  DocCompiler? compiler

  abstract Void run()

  LibNamespace ns() { compiler.ns }

  Void info(Str msg) { compiler.info(msg) }

  XetoCompilerErr err(Str msg, FileLoc loc, Err? err := null) { compiler.err(msg, loc, err) }

  XetoCompilerErr err2(Str msg, FileLoc loc1, FileLoc loc2, Err? err := null) { compiler.err2(msg, loc1, loc2, err) }

  Void bombIfErr() { if (!compiler.errs.isEmpty) throw compiler.errs.first }

  Void eachPage(|PageEntry| f)
  {
    compiler.pages.each(f)
  }

  static Str key(Obj x)
  {
    if (x is Spec) return ((Spec)x).qname
    if (x is Lib)  return ((Lib)x).name
    if (x is Dict) return ((Dict)x)._id.id
    throw Err("Cannot derive key: $x [$x.typeof]")
  }

}

