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
** Xeto compiler
**
internal class XetoCompiler
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make()
  {
    this.sys = ASys()
    this.depends = ADepends(this)
    this.usedBuildVars = [:]
  }

//////////////////////////////////////////////////////////////////////////
// Inputs
//////////////////////////////////////////////////////////////////////////

  ** Namespace used for depends resolution
  MNamespace? ns

  ** Environment
  XetoEnv env := XetoEnv.cur

  ** Logging
  XetoLog log := XetoLog.makeOutStream

  ** Input as in-memory file, zip file, or source directory
  File? input

  ** Dotted name of library to compile
  Str? libName

  ** If set, then build this libraries xetolib zip to this file
  File? build

  ** Are we building a xetolib zip
  Bool isBuild() { build != null }

  ** Build vars from source environment
  Str:Str srcBuildVars() { env.buildVars }

//////////////////////////////////////////////////////////////////////////
// Options
//////////////////////////////////////////////////////////////////////////

  ** Apply options
  Void applyOpts(Dict? opts)
  {
    if (opts == null) return

    log :=  XetoUtil.optLog(opts, "log")
    if (log != null) this.log = XetoCallbackLog(log)

    this.externRefs = opts.has("externRefs")
  }

//////////////////////////////////////////////////////////////////////////
// Pipelines
//////////////////////////////////////////////////////////////////////////

  ** Compile input directory to library
  Lib compileLib()
  {
    run([
      InitLib(),
      Parse(),
      ProcessPragma(),
      Resolve(),
      InheritSlots(),
      LoadBindings(),
      InferMeta(),
      ReifyMeta(),
      InheritMeta(),
      InferInstances(),
      ReifyInstances(),
      CheckErrors(),
      Assemble(),
      OutputZip()
    ])
    info("Compiled xetolib [${build?.osPath ?: libName}]")
    return lib.asm
  }

  ** Compile input to instance data
  Obj? compileData()
  {
    run([
      InitData(),
      Parse(),
      ProcessPragma(),
      Resolve(),
      InferInstances(),
      ReifyInstances(),
      CheckErrors(),
    ])
    return ast.asm
  }

  ** Parse only the lib.xeto file into version, doc, and depends.
  ** Must setup libName and input to the "lib.xeto" file
  FileLibVersion parseLibVersion()
  {
    run([
      InitLibVersion(),
      Parse(),
      ProcessPragma(),
    ])

    doc := lib.meta.getStr("doc") ?: ""
    dir := input.parent
    return FileLibVersion(libName, lib.version, dir, doc, depends.list)
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
    if (isBuild) log.info(msg)
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

  ** Log err message under slot name
  XetoCompilerErr errSlot(CSpec? slot, Str msg, FileLoc loc, Err? cause := null)
  {
    if (slot != null) msg = "Slot '$slot.name': $msg"
    return err(msg, loc, cause)
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
  Str autoName(Int i) { XetoUtil.autoName(i) }

  ** Make an interned ref
  Ref makeRef(Str id, Str? dis)
  {
    ref := internRefs[id]
    if (ref == null) internRefs[id] = ref = Ref(id, null)
    if (dis != null) ref.disVal = dis
    return ref
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  XetoCompilerErr[] errs := [,]        // err
  internal ASys sys                    // make
  internal ADepends depends            // make
  internal Duration? duration          // run
  internal Bool isLib                  // Init (false isData)
  internal Bool isSys                  // Init
  internal Bool isSysComp              // Init
  internal ANamespace? cns             // Init
  internal ADoc? ast                   // Parse (lib or data)
  internal ALib? lib                   // Parse (compileLib only)
  internal ADataDoc? data              // Parse (compileData only)
  internal ADict? pragma               // Parse
  internal Str:Str usedBuildVars       // Parse (build vars used by lib)
  internal Dict? json                  // JSON output
  internal Bool externRefs             // allow unresolved refs to compile
  private Str:Ref internRefs := [:]    // makeRef
}

