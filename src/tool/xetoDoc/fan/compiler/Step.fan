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

  DocId id(Str qname)
  {
    compiler.ids.getChecked(qname)
  }

  DocSummary summary(Str qname)
  {
    compiler.summaries.getChecked(qname)
  }

  Void eachLib(|Lib| f)
  {
    compiler.libs.each(f)
  }

  Void eachSpec(|Spec| f)
  {
    compiler.libs.each |lib|
    {
      lib.specs.each(f)
    }
  }

}

