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
    genSetters      = build["setters"] as Bool ?: false
    genDicts        = build["dicts"]   as Bool ?: false
    genAsyncMethods = build["asyncMethods"] as Bool ?: false
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
    libs.each |lib|
    {
      lib.types.each |type|
      {
        if (includeType(type)) types.add(type)
      }
    }
    this.types = types.sort
  }

  Bool includeType(Spec type)
  {
    if (type.name.startsWith("_")) return false
    return true
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


    //w("//force").nl
    genOpen
    genTypeMixin(type)
    genTypeDict(type)
    genClose(file)
  }

  private Bool hasDict(Spec type)
  {
    genDicts && type.missing("abstract")
  }

  private Void genTypeMixin(Spec type)
  {
    name := type.name
    baseName := type.base.name
    if (baseName == "Dict") baseName = "Item"

    w("**").nl
    fandoc(type, 0)
    w("**").nl
    if (type.meta.has("nodoc")) w("@NoDoc ")
    w("@Js").nl
    w("mixin ").w(name).w(" : ").w(baseName).nl
    w("{").nl
    nl

    // dict constructor
    if (hasDict(type))
    {
      w("  ** Constructor to wrap dict data").nl
      w("  static new makeDict(Dict dict)").nl
      w("  {").nl
      w("    ").w(name).w("Dict(dict)").nl
      w("  }").nl
      nl
    }

    // slot getter/setters/calls
    type.slotsOwn.each |slot|
    {
      if (includeSlot(slot))  genSlot(slot)
    }

    w("}").nl
  }

  private Void genTypeDict(Spec type)
  {
    if (!hasDict(type)) return

    name := type.name

    section("${name}Dict", '*')

    w("**").nl
    w("** Dict implementation for $name").nl
    w("**").nl
    w("@NoDoc @Js").nl
    w("const class ").w(name).w("Dict").w(": ItemDict, ").w(name).nl
    w("{").nl
    w("  new make(Dict dict) : super(dict) {}").nl
    w("}").nl
  }

  private Bool includeSlot(Spec slot)
  {
    if (slot.type.isMarker) return false
    if (slot.name == "id") return false // will move this to Item
    if (slot.name == "dis") return false // need to make Dict.dis no params
    return true
  }

  private Void genSlot(Spec slot)
  {
    fandoc(slot, 2)
    if (slot.type.isFunc)
      genMethod(slot)
    else if (genSetters && slot.missing("readonly"))
      genField(slot)
    else
      genGetter(slot)
    nl
  }

  private Void genField(Spec slot)
  {
    w("  ").slotFacets(slot).w("virtual ").slotTypeSig(slot).sp.w(slot.name).nl
    w("  {").nl
    w("    get { get(\"").w(slot.name).w("\") }").nl
    w("    set { set(\"").w(slot.name).w("\", it) }").nl
    w("  }").nl

  }

  private Void genGetter(Spec slot)
  {
    w("  ").slotFacets(slot).w("virtual ").slotTypeSig(slot).sp.w(slot.name).w("()").nl
    w("  {").nl
    w("    get(\"").w(slot.name).w("\")").nl
    w("  }").nl
  }

  private Void genMethod(Spec slot)
  {
    isAsync := genAsyncMethods
    returns := slot.slot("returns")

    // @NoDoc virtual
    w("  ").slotFacets(slot).w("virtual ")

    // return type
    if (isAsync)
      w("Void")
    else
      slotTypeSig(returns)

    // name
    sp.w(slot.name)

    // params (a, b, [cb])
    w("(")
    paramNames := Str[,]
    eachParam(slot) |param, i|
    {
      paramNames.add(param.name)
      comma.slotTypeSig(param).w(" ").w(param.name)
    }
    if (isAsync) comma.w("|Err?, ").slotTypeSig(returns, true).w("| cb")
    w(")").nl

    callName := isAsync ? "callAsync" : "call"
    args := paramNames.isEmpty ? "," : paramNames.join(", ")
    cbArg := isAsync ? ", cb" : ""

    w("  {").nl
    w("    ").w(callName).w("(\"").w(slot.name).w("\", [").w(args).w("]").w(cbArg).w(")").nl
    w("  }").nl
  }

  private Void eachParam(Spec slot, |Spec, Int| f)
  {
    i := 0
    slot.slots.each |x|
    {
      if (x.name != "returns") f(x, i++)
    }
  }

  private This slotFacets(Spec slot)
  {
    if (slot.has("nodoc")) w("@NoDoc ")
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private This slotTypeSig(Spec slot, Bool forceMaybe := false)
  {
    if (slot.type.isList)
    {
      of := slot.of
      if (of.name.startsWith("_")) of = slot.lib.type(of.name).base // nested specs such as List<of:Ref<of:Foo>>
      slotTypeSig(of).w("[]")
    }
    else
    {
      w(slot.type.name)
    }
    if (slot.isMaybe || forceMaybe) w("?")
    return this
  }

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

  private This section(Str title, Int char)
  {
    nl
    75.times { buf.addChar(char) }; nl
    w("** ").w(title).nl
    75.times { buf.addChar(char) }; nl
    nl
    return this
  }

  private This w(Obj x) { buf.add(x); return this }

  private This sp() { buf.addChar(' '); return this  }

  private This nl() { buf.addChar('\n'); return this }

  private This comma()
  {
    if (buf[-1] != '(') buf.add(", ")
    return this
  }

  private Void genOpen()
  {
    this.buf = StrBuf()
    w("using xeto::Item").nl
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
    if (lines.size < 4) return true
    if (!lines[1].trim.isEmpty) return true

    // compare old body to new body
    oldBody := lines[2..-1].join("\n")
    return oldBody.trim != newBody.trim
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private File? outDir          // output directory for generated fantom source files
  private Dict? build           // parsed build.xeto instructions
  private Bool genSetters       // gen setters flag
  private Bool genDicts         // gen dicts flag
  private Bool genAsyncMethods  // gen asyncMethods flag
  private Spec[]? types         // type specs to generate
  private StrBuf? buf           // current file contents without header
  private Int numRewrote        // number of files we rewrote that changed
}