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
** Xeto documentation compiler
**
class DocCompiler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** It-block Constructor
  new make(|This| f) { f(this) }

//////////////////////////////////////////////////////////////////////////
// Inputs
//////////////////////////////////////////////////////////////////////////

  ** Namespace to generate
  const LibNamespace ns

  ** Libs to generate
  const Lib[] libs

  ** Output directory
  const File outDir

  ** Logging
  XetoLog log := XetoLog.makeOutStream

//////////////////////////////////////////////////////////////////////////
// Options
//////////////////////////////////////////////////////////////////////////

  ** Apply options
  Void applyOpts(Dict? opts)
  {
    if (opts == null) return

    log :=  XetoUtil.optLog(opts, "log")
    if (log != null) this.log = XetoCallbackLog(log)
  }

//////////////////////////////////////////////////////////////////////////
// Pipelines
//////////////////////////////////////////////////////////////////////////

  ** Compile input directory to library
  This compile()
  {
    run([
      GenIds(),
      GenSummaries(),
      GenLibs(),
      GenSpecs(),
    ])
    return this
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
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Log info message
  Void info(Str msg)
  {
    log.info(msg)
  }

  ** Log warning message
  Void warn(Str msg, FileLoc loc, Err? cause := null)
  {
    log.warn(msg, loc, cause)
  }

  ** Log err message
  XetoCompilerErr err(Str msg, FileLoc loc, Err? cause := null)
  {
    err := XetoCompilerErr(msg, loc, cause)
    errs.add(err)
    log.err(msg, loc, cause)
    return err
  }

  ** Log err message with two locations of duplicate identifiers
  XetoCompilerErr err2(Str msg, FileLoc loc1, FileLoc loc2, Err? cause := null)
  {
    err := XetoCompilerErr(msg, loc1, cause)
    errs.add(err)
    log.err("$msg [$loc2]", loc1, cause)
    return err
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  XetoCompilerErr[] errs := [,]         // err
  internal Duration? duration           // run
  internal [Str:DocId]? ids             // GenIds keyed by qnames
  internal [Str:DocSummary]? summaries  // GenSummaries keyed by qnames
}

