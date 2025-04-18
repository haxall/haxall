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

  ** Static utility which can be easily used for reflection
  static Void runCompiler(LibNamespace ns, File outDir)
  {
    c := DocCompiler
    {
      it.ns     = ns
      it.libs   = ns.libs
      it.outDir = outDir
    }
    c.compile
  }

  ** It-block Constructor
  new make(|This| f) { f(this) }

//////////////////////////////////////////////////////////////////////////
// Inputs
//////////////////////////////////////////////////////////////////////////

  ** Namespace to generate
  const LibNamespace ns

  ** Libs to generate
  const Lib[] libs

  ** Output directory or if null then output to in-mem files field
  const File? outDir

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
      StubPages(),
      GenSummaries(),
      GenPages(),
      WriteJson(),
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
      if (outDir != null)
        info("Compiled docs $numFiles files in ${duration.toLocale} [$outDir.osPath]")
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

  ** Lookup page entry for lib, spec, instance
  PageEntry page(Obj def)
  {
    pages.getChecked(key(def))
  }

  ** Get page entry key for lib, spec, instance
  static Str key(Obj def)
  {
    if (def is Spec) return ((Spec)def).qname
    if (def is Lib)  return ((Lib)def).name
    if (def is Dict) return ((Dict)def)._id.id
    throw Err("Cannot derive key: $def [$def.typeof]")
  }

  ** Generate an auto name of "_0", "_1", etc
  Str autoName(Int i)
  {
    // optimize to reuse "_0", "_1", etc per compilation
    if (i < autoNames.size) return autoNames[i]
    if (i != autoNames.size) throw Err(i.toStr)
    s := i.toStr
    n := StrBuf(1+s.size).addChar('_').add(s).toStr
    autoNames.add(n)
    return n
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  XetoCompilerErr[] errs := [,]       // err
  Duration? duration                  // run
  [Str:PageEntry]? pages              // StubPages
  PageEntry[]? libPages               // StubPages
  File[] files := [,]                 // WriteJson if generating in-mem
  Int numFiles                        // WriteJson if generating to outDir
  private Str[] autoNames := [,]      // autoName
}

