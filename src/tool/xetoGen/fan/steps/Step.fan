//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Base class for GenCompiler steps
**
abstract internal class Step
{
  GenCompiler? compiler

  abstract Void run()

  Namespace ns() { compiler.ns }

  Ast ast() { compiler.ast }

  APod[] pods() { compiler.ast.pods }

  Void info(Str msg) { compiler.info(msg) }

  Void warn(Str msg, FileLoc loc, Err? cause := null) { compiler.warn(msg, loc, cause) }

  XetoCompilerErr err(Str msg, FileLoc loc, Err? cause := null) { compiler.err(msg, loc, cause) }

  Void bombIfErr() { if (!compiler.errs.isEmpty) throw compiler.errs.first }
}

