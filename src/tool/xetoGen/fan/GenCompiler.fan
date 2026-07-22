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
** Gen compiler: sync Fantom source code from xeto specs
**
class GenCompiler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** It-block constructor
  new make(|This|? f := null) { if (f != null) f(this) }

//////////////////////////////////////////////////////////////////////////
// Inputs
//////////////////////////////////////////////////////////////////////////

  ** Info, warning, and error logging
  XetoLog logger := XetoLog.makeOutStream

  ** Explicit lib names to generate or null for all matched pods
  Str[]? libNames

  ** Report what would change without writing any files
  Bool preview

  ** Xeto lib namespace
  Namespace ns := XetoEnv.cur.createInstalledNamespace

//////////////////////////////////////////////////////////////////////////
// Pipeline
//////////////////////////////////////////////////////////////////////////

  ** Run the compiler pipeline
  Void compile()
  {
    run([
      FindPods(),
      FindTypes(),
    ])
  }

  ** Run the pipeline with the given steps
  internal This run(Step[] steps)
  {
    try
    {
      t1 := Duration.now
      steps.each |step|
      {
        step.compiler = this
        step.run
      }
      t2 := Duration.now
      duration = t2 - t1
      info("Done [$duration.toLocale]")
      return this
    }
    catch (XetoCompilerErr e)
    {
      throw e
    }
    catch (Err e)
    {
      throw err("Internal compiler error", FileLoc.unknown, e)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Dump the parsed AST for debugging
  Void dump(Console con := Console.cur)
  {
    ast.dump(con)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Log info message
  Void info(Str msg)
  {
    logger.info(msg)
  }

  ** Log warning message
  Void warn(Str msg, FileLoc loc, Err? cause := null)
  {
    logger.warn(msg, loc, cause)
  }

  ** Log err message
  XetoCompilerErr err(Str msg, FileLoc loc, Err? cause := null)
  {
    err := XetoCompilerErr(msg, loc, cause)
    errs.add(err)
    logger.err(msg, loc, cause)
    return err
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  XetoCompilerErr[] errs := [,]          // err
  internal Duration? duration            // run
  internal Ast? ast                      // FindPods
}

