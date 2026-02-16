//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

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
  const Namespace ns

  ** Libs to generate
  const Lib[] libs

  ** Output directory or if null then output to in-mem files field
  const File? outDir

  ** Extra pages to include the compilation.  These pages are
  ** generated to JSON or HTML and used to resolve shortcut links
  DocPage[] extraPages := [,]

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

  ** Compile to HTML files
  This compileHtml()
  {
    if (outDir == null) throw Err("Must config outDir")
    this.mode = DocCompileMode.html
    run([
      GenPages(),
      WriteHtml(),
    ])
    return this
  }


  ** Compile to JSON files (if outDir null, then in-memory files)
  This compileJson()
  {
    this.mode = DocCompileMode.json
    run([
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
      {
        info("Compiled docs $numFiles files in ${duration.toLocale} [$outDir.osPath]")
        if (numWarns > 0) info("*** $numWarns WARNINGS ***")
      }
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
    numWarns++
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

  DocCompileMode? mode                // init
  DocNamespace? docns                 // can be passed in or lazily created
  XetoCompilerErr[] errs := [,]       // err
  Duration? duration                  // run
  DocPage[] pages := [,]              // GenPages
  Int numFiles                        // WriteHtml, WriteJson
  Int numWarns                        // warn
  private Str[] autoNames := [,]      // autoName
}

**************************************************************************
** DocCompileMode
**************************************************************************

@Js
enum class DocCompileMode
{
  html,
  json

  Bool isHtml() { this === html }

  Bool isJson() { this === json }
}

