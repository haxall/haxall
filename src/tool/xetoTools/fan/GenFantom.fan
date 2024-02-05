//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Feb 2024  Brian Frank  Creation
//

using util
using haystack::Dict
using xeto

internal class GenFantom : XetoCmd
{
  override Str name() { "gen-fantom" }

  override Str summary() { "Compile xeto specs into Fantom source code" }

  @Arg { help = "File path to build.xeto" }
  File? buildFile

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    init
    parseBuildFile
    readInputs
    genTypes
    echo("Rewrote $numRewrote files")
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Init
//////////////////////////////////////////////////////////////////////////

  ** Check inputs and set up file paths
  private Void init()
  {
    // check build file exists
    if (buildFile == null || !buildFile.exists) throw Err("Build file not found: $buildFile")

    // sanity check that build.xeto is peer to build.fan
    srcDir := buildFile.parent
    if (!srcDir.plus(`build.fan`).exists) throw Err("Expecting build.fan in $srcDir")
    this.outDir = srcDir + `fan/`
  }

//////////////////////////////////////////////////////////////////////////
// Parse Build File
//////////////////////////////////////////////////////////////////////////

  ** Parse the build.xeto file as the build dict instructions
  private Void parseBuildFile()
  {
    this.build = env.compileData(buildFile.readAllStr) as Dict
    if (build == null) throw Err("Root of build file must be a dict")

    // read flags
    genSetters = build["setters"] as Bool ?: false
  }

//////////////////////////////////////////////////////////////////////////
// Read Inputs
//////////////////////////////////////////////////////////////////////////

  ** Read the configuration from build.xeto to setup types/funcs to generate
  private Void readInputs()
  {
    // get lib to compile
    libs := Lib[,]
    libNames := build["libs"] as List ?: throw Err("Must define 'libs' as list of lib names")
    libNames.each |name|
    {
      libs.add(env.lib(name))
    }

    // get type specs to generate - all of them right now
    types := Spec[,]
    libs.each |lib| { types.addAll(lib.types) }
    this.types = types.sort
  }

//////////////////////////////////////////////////////////////////////////
// Gen Types
//////////////////////////////////////////////////////////////////////////

  ** Generate a Fantom source file per type
  private Void genTypes()
  {
    types.each |type| { genType(type) }
  }

  private Void genType(Spec type)
  {
    name := type.name
    file := outDir + `${name}.fan`

    genOpen

    //w("//force").nl

    fandoc(type, 0)
    w("mixin ").w(name)
    if (type.base.qname != "sys::Dict")
    {
      w(" : ").w(type.base.name)
    }
    w(" {").nl
    nl
    type.slotsOwn.each |slot|
    {
      if (includeSlot(slot))  genSlot(slot)
    }
    w("}").nl
    genClose(file)
  }

  private Bool includeSlot(Spec slot)
  {
    if (slot.type.isMarker) return false
    return true
  }

  private Void genSlot(Spec slot)
  {
    fandoc(slot, 2)
    if (genSetters && slot.missing("readonly"))
      genField(slot)
    else
      genGetter(slot)
    nl
  }

  private Void genField(Spec slot)
  {
    w("  abstract ").typeSig(slot.type).sp.w(slot.name).nl
  }

  private Void genGetter(Spec slot)
  {
    w("  abstract ").typeSig(slot.type).sp.w(slot.name).w("()").nl
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private This fandoc(Spec spec, Int indent)
  {
    doc := spec["doc"] as Str
    if (doc == null) return this

    lines := doc.splitLines
    lines.each |line|
    {
      w(Str.spaces(indent)).w("** ").w(line).nl
    }
    return this
  }

  private This typeSig(Spec type)
  {
    w(type.name)
    if (type.isMaybe) w("?")
    return this
  }

  private This w(Obj x) { buf.add(x); return this }

  private This sp() { buf.addChar(' '); return this  }

  private This nl() { buf.addChar('\n'); return this }

  private Void genOpen()
  {
    this.buf = StrBuf()
    w("using haystack").nl
    nl
  }

  private Void genClose(File file)
  {
    newBody := buf.toStr
    if (!isChanged(file, newBody)) return

    echo("Gen [$file.osPath]")
    numRewrote++

    out := file.out
    out.printLine("// Auto generated $Date.today.toLocale")
    out.printLine
    out.print(newBody)
    out.close
  }

  private Bool isChanged(File file, Str newBody)
  {
    if (!file.exists) return true

    // strip header
    lines := file.readAllLines
    if (lines.size < 5) return true
    if (!lines[3].trim.isEmpty) return true

    // compare old body to new body
    oldBody := lines[4..-1].join("\n")
    return oldBody.trim != newBody.trim
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private File? outDir        // output directory for generated fantom source files
  private Dict? build         // parsed build.xeto instructions
  private Bool genSetters     // gen setters flag
  private Spec[]? types       // type specs to generate
  private StrBuf? buf         // current file contents without header
  private Int numRewrote      // number of files we rewrote that changed
}