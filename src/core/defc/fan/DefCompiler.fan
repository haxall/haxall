//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Jun 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using compilerDoc
using haystack
using def

**
** DefCompiler
**
class DefCompiler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make()
  {
    this.intern  = InternFactory()
    this.symbols = CSymbolFactory(intern)
  }

//////////////////////////////////////////////////////////////////////////
// Inputs
//////////////////////////////////////////////////////////////////////////

  ** Error and warning logging
  Log log := Log.get("defc")

  ** Output directory for compiler/documentation results
  File? outDir

  ** Callback for each document file generated.  If left as
  ** null it will output a file to the 'outDir' using the ".html"
  ** file extension.  If non-null then no file extension is applied
  ** and only the body content is generated
  |DocFile|? onDocFile

  ** Callback used to filter which defs are included in the docs.
  ** If a lib def itself returns false then all of its defs are excluded
  ** too.  The default implementation only checks for the 'nodoc' marker.
  ** If you override the default implmentation, then your custom
  ** callback must check for 'nodoc' too.
  |CDef->Bool| includeInDocs := |CDef def->Bool| { !def.isNoDoc }

  ** Default input libraries
  CompilerInput[] inputs := [
    CompilerInput.makePodName("ph"),
    CompilerInput.makePodName("phScience"),
    CompilerInput.makePodName("phIoT"),
    CompilerInput.makePodName("phIct"),
    CompilerInput.makePodName("docHaystack"),
  ]

  ** Factory to use for building Namespace and Features
  DefFactory factory := DefFactory()

//////////////////////////////////////////////////////////////////////////
// Compile
//////////////////////////////////////////////////////////////////////////

  ** Compile pods to an index
  CIndex compileIndex()
  {
    run([,]).index
  }

  ** Compile to a Namespace instance
  Namespace compileNamespace()
  {
    run(DefCompilerStep[,]).ns
  }

  ** Compile into DefDocEnv model (but don't generate HTML files)
  DefDocEnv compileDocEnv()
  {
    run([GenDocEnv(this)]).docEnv
  }

  ** Compile into HTML documentation under outDir
  This compileDocs()
  {
    run([GenDocEnv(this), GenDocs(this)])
  }

  ** Compile all all dist formats and HTML
  This compileAllFormats()
  {
    backend := DefCompilerStep[GenDocs(this)]
    GenGrid.formats.each |format| { backend.add(GenGrid(this, format)) }
    return run(backend)
  }

  ** Compile into one or more formats from command line Main
  This compileMain(Str[] formats)
  {
    if (formats.contains("dist")) return compileDist
    backend := DefCompilerStep[,]
    formats.each |format|
    {
      if (format == "html")
        backend.add(GenDocEnv(this)).add(GenDocs(this))
      else
        backend.add(GenGrid(this, format))
    }
    return run(backend)
  }

  ** Compile into dist zip file
  This compileDist()
  {
    backend := DefCompilerStep[,]
    backend.add(GenDocEnv(this)).add(GenDocs(this))
    GenGrid.formats.each |format| { backend.add(GenGrid(this, format)) }
    backend.add(GenDist(this))
    return run(backend)
  }

  ** Common frontend steps
  private DefCompilerStep[] frontend()
  {
    [Scan(this),
     Parse(this),
     Reflect(this),
     Index(this),
     Resolve(this),
     Taxonify(this),
     ApplyX(this),
     Normalize(this),
     Inherit(this),
     Validate(this),
     GenNamespace(this),
     GenProtos(this)]
  }

  ** Run the pipeline of common frotend and given backend steps
  private This run(DefCompilerStep[] backend)
  {
    try
    {
      t1 := Duration.now
      steps := frontend.addAll(backend)
      this.genDocEnv = steps.any |step| { step is GenDocEnv }

      steps.each |step|
      {
        step.run
      }

      t2 := Duration.now
      info("Compiled defs [" + stats(t2-t1) + "]")
      return this
    }
    catch (CompilerErr e)
    {
      throw e
    }
    catch (Err e)
    {
      throw err("Internal compiler error", CLoc.none, e)
    }
  }

  private Str stats(Duration dur)
  {
    s := StrBuf()
    s.add(libs.size).add(" libs, ")
    s.add(index.defs.size).add(" defs, ")
    if (index.hasProtos) s.add(index.protos.size).add(" protos, ")
    s.add(dur.toLocale)
    return s.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Log info message
  Void info(Str msg)
  {
    log.info(msg)
  }

  ** Log err message
  Void warn(Str msg, CLoc loc, Err? cause := null)
  {
    log.warn("$msg [$loc]", cause)
  }

  ** Log err message
  CompilerErr err(Str msg, CLoc loc, Err? cause := null)
  {
    err := CompilerErr(msg, loc, cause)
    errs.add(err)
    log.err("$msg [$loc]", cause)
    return err
  }

  ** Log err message with two locations of duplicate identifiers
  CompilerErr err2(Str msg, CLoc loc1, CLoc loc2, Err? cause := null)
  {
    err := CompilerErr(msg, loc1, cause)
    errs.add(err)
    log.err("$msg [$loc1, $loc2]", cause)
    return err
  }

  ** Initialize output directory
  once File initOutDir()
  {
    dir := this.outDir
    if (dir == null) throw err("DefCompiler.outDir not configured", CLoc.inputs)
    if (!dir.isDir) throw err("DefCompiler.outDir is not dir: $dir", CLoc.inputs)
    dir.delete
    dir.create
    return dir
  }

  ** Callback to undefine specific defs during compilation
  virtual Bool undefine(Dict def) { false }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  internal InternFactory intern         // make
  internal CompilerErr[] errs := [,]    // err
  internal Bool genDocEnv               // DocGenEnv one of our steps?
  internal CSymbolFactory symbols       // Scan, Parse
  internal CSymbol:CLib libs := [:]     // Scan
  internal Str:DocPod manuals := [:]    // Scan
  internal CIndex? index                // Index
  Namespace? ns                         // GenNamespace
  internal Grid? grid                   // GenGrid
  internal DefDocEnv? docEnv            // GenDocEnv
}

