//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   09 Feb 2022  Matthew Giannini  Creation
//

using util
using haystack
using hx

internal class StubCli : HxCli
{

//////////////////////////////////////////////////////////////////////////
// Options
//////////////////////////////////////////////////////////////////////////

  @Opt { help = "pod type to stub: resource | fantom | conn" }
  Str type := "fantom"

  @Opt { help = "target base directory" }
  File out := File(`./`)

  @Opt { help = "description of the pod"}
  Str? desc

  @Opt { help = "author name" }
  Str? author

  @Opt { help = "organization name" }
  Str? org

  @Opt { help = "organization website" }
  Str? orgUri

  @Opt { help = "project name" }
  Str? proj

  @Opt { help = "project website" }
  Str? projUri

  @Opt { help = "source code license" }
  Str? lic

  @Opt { help = "version control name (e.g. Git, Mercurial)" }
  Str? vcs

  @Opt { help = "URL where the source code is hosted" }
  Str? vcsUri

  @Opt { help = "generate skyarc.trio (default = false)" }
  Bool skyarc

  @Opt { help = "copy build.fan metadata from the given pod" }
  Str? meta

  @Arg { help = "Haxall library name" }
  Str? libName

//////////////////////////////////////////////////////////////////////////
// Usage
//////////////////////////////////////////////////////////////////////////

  override Int usage(OutStream out := Env.cur.out)
  {
    c := super.usage(out)
    out.printLine
    out.printLine(
      """Notes: You will be prompted for any unspecified options that don't have default values.
         """)
    return c
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Cache today's date
  private const Date today := Date.today

  ** Prefix to use for generated Fantom types
  **   libName = "acmeFoo" => "Foo"
  private Str? typePrefix

  ** Library org prefix
  **   libName = "acmeFoo" => "acme"
  private Str? libOrg

  ** The lib def name
  private Str defName() { isHx ? typePrefix.decapitalize : libName }

  ** Standard macros for use across generating all files
  private Str:Str stdMacros := [:]

  private File? buildFile
  private File? podFandocFile
  private File? libDefFile
  private File? libFile
  private File? fanFuncsFile
  private File? connDispatchFile
  private File? axonFuncsFile
  private File? connDefFile
  private File? connPointDefFile
  private File? skyarcFile

//////////////////////////////////////////////////////////////////////////
// HxCli
//////////////////////////////////////////////////////////////////////////

  override Str name() { "stub" }

  override Str summary() { "Stub a new Haxall pod" }

  override Int run()
  {
    loadMeta
    promptInput
    if (!checkInput) return 1
    initMacros
    genFileNames
    if (!confirm) return 1
    genBuild
    genLibDef
    genLib
    genFanFuncs
    genAxonFuncs
    genConnDef
    genPointDef
    genConnDispatch
    genSkyarc
    genPodFandoc
    printLine("Done!")
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Load Meta
//////////////////////////////////////////////////////////////////////////

  private Void loadMeta()
  {
    if (meta == null) return
    pod := Pod.find(meta)
    if (org == null) this.org = pod.meta["org.name"]
    this.orgUri   = pod.meta["org.uri"]
    this.proj     = pod.meta["proj.name"]
    this.projUri  = pod.meta["proj.uri"]
    this.lic      = pod.meta["license.name"]
    this.vcs      = pod.meta["vcs.name"]
    this.vcsUri   = pod.meta["vcs.uri"]
  }

//////////////////////////////////////////////////////////////////////////
// Prompt
//////////////////////////////////////////////////////////////////////////

  private Void promptInput()
  {
    // general
    if (org == null)
    {
      this.org = prompt("Organization name").trimToNull
    }
    if (author == null)
    {
      this.author = promptDef("Author", Env.cur.user)
    }
    if (desc == null)
    {
      this.desc = prompt("Pod summary")
    }

    // build.fan
    if (orgUri == null)
    {
      this.orgUri = prompt("Organization URL")
    }
    if (proj == null)
    {
      this.proj = promptDef("Project Name", "Haxall")
    }
    if (projUri == null)
    {
      def := proj== "Haxall" ? "https://haxall.io" : ""
      this.projUri = promptDef("Project URL", def)
    }
    isHaxall := proj == "Haxall"
    if (lic == null)
    {
      this.lic = promptDef("License Name", "Academic Free License 3.0")
    }
    if (vcs == null)
    {
      def := isHaxall ? "Git" : ""
      this.vcs = promptDef("VCS Name", def)
      if (vcs.isEmpty) vcsUri = ""
    }
    if (vcsUri == null)
    {
      def := isHaxall ? "https://github.com/haxall/haxall" : ""
      this.vcsUri = promptDef("VCS URL", def)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Check Input
//////////////////////////////////////////////////////////////////////////

  private Bool checkInput()
  {
    // type
    switch (type)
    {
      case "conn":
      case "fantom":
      case "resource":
        // fall-through
        ok := true
      default:
        return fatal("Invalid pod type: $type")
    }
    // pod name
    if (!Etc.isTagName(libName)) return fatal("Library name must be a valid tag name: $libName")
    if (libName.endsWith("Ext")) return fatal("Library name must not end with 'Ext': $libName")
    idx := libName.chars.findIndex { it.isUpper }
    if (idx == 0) return fatal("Library name must start with lowercase prefix: $libName")
    this.libOrg     = libName[0..<idx]
    this.typePrefix = isHx ? libName[idx..-1] : libName.capitalize

    // header
    if (org == null)    return fatal("Must specify an organization")
    if (author == null) return fatal("Must specify an author")

    // out
    out = out.normalize.uri.plusSlash.toFile + `$libName/`

    // sanity check resource pod
    if (isResource)
    {
      if (containsFcode)
        return fatal("Cannot create resource pod.\n ${name} already exists and contains Fantom code: $out")
    }

    // all ok
    return true
  }

  private Bool fatal(Str msg)
  {
    printLine
    err(msg)
    printLine
    usage
    return false
  }


//////////////////////////////////////////////////////////////////////////
// Init Macros
//////////////////////////////////////////////////////////////////////////

  private Void initMacros()
  {
    stdMacros["org"]        = this.org
    stdMacros["libName"]    = this.libName
    stdMacros["defName"]    = this.defName
    stdMacros["typePrefix"] = this.typePrefix
    stdMacros["header"]     = applyTemplate(`header.template`, headerApply)
  }

  private |Str->Str?| headerApply := |key->Str?| {
    switch (key)
    {
      case "year":    return today.year.toStr
      case "date":    return today.toLocale("DD MMM YYYY")
      case "org":     return this.org
      case "author":  return this.author
      case "license": return isHx
        ? "Licensed under the Academic Free License version 3.0"
        : this.lic
      default: return null
    }
  }

//////////////////////////////////////////////////////////////////////////
// Generate File Names
//////////////////////////////////////////////////////////////////////////

  private Void genFileNames()
  {
    buildFile     = out.plus(`build.fan`)
    podFandocFile = out.plus(`pod.fandoc`)
    libDefFile    = out.plus(`lib/lib.trio`)
    if (isResource)
    {
      axonFuncsFile = out.plus(`lib/funcs.trio`)
    }
    else
    {
      libFile      = out.plus(`fan/${typePrefix}Lib.fan`)
      fanFuncsFile = out.plus(`fan/${typePrefix}Funcs.fan`)
      if (isConn)
      {
        connDefFile = out.plus(`lib/conn.trio`)
        connPointDefFile = out.plus(`lib/point.trio`)
        connDispatchFile = out.plus(`fan/${typePrefix}Dispatch.fan`)
      }
      if (skyarc) skyarcFile = out.plus(`lib/skyarc.trio`)
    }
  }

  private Bool confirm()
  {
    printLine("=== Stub $libName.toCode ${type} ===")
    printLine("Org:     $org")
    printLine("Author:  $author")
    printLine("Summary: $desc")
    printLine

    printLine("Pod Meta")
    printLine("  org.uri:".padr(22) + this.orgUri)
    printLine("  proj.name:".padr(22) + this.proj)
    printLine("  proj.uri:".padr(22) + this.projUri)
    printLine("  license.name:".padr(22) + this.lic)
    if (vcs != null)
    {
      printLine("  vcs.name:".padr(22) + this.vcs)
      printLine("  vcs.uri:".padr(22) + this.vcsUri)
    }
    printLine

    printLine("Generate Files:")
    typeof.fields.each |field|
    {
      if (!field.name.endsWith("File")) return
      f := field.get(this) as File
      if (f != null)
      {
        s := "  $field.name.toDisplayName:".padr(22)
        s += f.osPath
        if (f.exists) s += " (OVERWRITE!!!)"
        printLine(s)
      }
    }

    cont :=  promptConfirm("Continue")
    if (!cont) printLine("Cancelled")
    return cont
  }

//////////////////////////////////////////////////////////////////////////
// Gen Build
//////////////////////////////////////////////////////////////////////////

  ** Write build.fan
  private Void genBuild()
  {
    // build basic dependencies
    buildPod := Pod.find("build")
    fanVer := buildPod.config("fan.depend") == null ? "1.0" : "@{fan.depend}"

    hxVer  := typeof.pod.version.segments[0..1].join(".")
    if (buildPod.config("hx.depend") != null) hxVer = "@{hx.depend}"
    else if (buildPod.config("skyarc.depend") != null) hxVer = "@{skyarc.depend}"

    depends := ["sys $fanVer"]
    if (!isResource)
    {
      // fantom
      depends.add("concurrent $fanVer")
             .add("inet $fanVer")

      // haxall
      depends.add("haystack $hxVer")
             .add("axon $hxVer")
             .add("folio $hxVer")
             .add("hx $hxVer")

      if (isConn)
      {
        depends.add("hxConn $hxVer")
      }
    }

    // source directories
    srcDirs := Uri[,]
    if (!isResource)
    {
      srcDirs.add(`fan/`)
    }

    // resource directories
    resDirs := Uri[`lib/`]

    // apply template
    content := applyTemplate(`build.fan.template`) |key->Str?|
    {
      switch (key)
      {
        case "desc":        return this.desc
        case "orgUri":      return this.orgUri
        case "proj":        return this.proj
        case "projUri":     return this.projUri
        case "lic":         return this.lic
        case "vcs":         return this.vcs
        case "vcsUri":      return this.vcsUri
        case "depends":     return buildList(depends)
        case "srcDirs":     return buildList(srcDirs)
        default: return null
      }
    }

    buildFile.out.writeChars(content).close
  }

  private Str buildList(Obj[] list)
  {
    if (list.isEmpty) return ","
    s := list.join(",\n") |item| { return Str.spaces(6) + item->toCode }
    return s
  }

//////////////////////////////////////////////////////////////////////////
// Gen lib.trio
//////////////////////////////////////////////////////////////////////////

  private Void genLibDef()
  {
    depends := ["^lib:ph", "^lib:axon", "^lib:hx"]
    if (isConn) depends.add("^lib:conn")

    libDefFile.out.writeChars(applyTemplate(`lib.trio.template`) |key->Str?| {
      switch (key)
      {
        case "depends":  return depends.join(", ")
        case "typeName": return isResource
          ? ""
          : "typeName: \"${libName}::${typePrefix}Lib\""
      }
      return null
    }).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen Lib.fan
//////////////////////////////////////////////////////////////////////////

  private Void genLib()
  {
    if (libFile == null) return
    template := isConn ? `connLib.fan.template` : `lib.fan.template`
    libFile.out.writeChars(applyTemplate(template)).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen Fantom Funcs
//////////////////////////////////////////////////////////////////////////

  private Void genFanFuncs()
  {
    if (fanFuncsFile == null) return
    fanFuncsFile.out.writeChars(applyTemplate(`funcs.fan.template`)).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen Axon Funcs
//////////////////////////////////////////////////////////////////////////

  private Void genAxonFuncs()
  {
    if (axonFuncsFile == null) return
    axonFuncsFile.out.writeChars(applyTemplate(`funcs.trio.template`)).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen conn.trio
//////////////////////////////////////////////////////////////////////////

  private Void genConnDef()
  {
    if (connDefFile == null) return
    connDefFile.out.writeChars(applyTemplate(`conn.trio.template`) |key->Str?| {
      if (key == "connFeatures")
      {
        // TODO: more features
        return "{pollMode:\"buckets\"}"
      }
      return null
    }).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen point.trio
//////////////////////////////////////////////////////////////////////////

  private Void genPointDef()
  {
    if (connPointDefFile == null) return
    connPointDefFile.out.writeChars(applyTemplate(`connPoint.trio.template`)).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen Conn Dispatch
//////////////////////////////////////////////////////////////////////////

  private Void genConnDispatch()
  {
    if (connDispatchFile == null) return
    connDispatchFile.out.writeChars(applyTemplate(`connDispatch.fan.template`)).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen skyarc.trio
//////////////////////////////////////////////////////////////////////////

  private Void genSkyarc()
  {
    if (skyarcFile == null) return
    skyarcFile.out.writeChars(applyTemplate(`skyarc.trio.template`)).close
  }

//////////////////////////////////////////////////////////////////////////
// Gen pod.fandoc
//////////////////////////////////////////////////////////////////////////

  private Void genPodFandoc()
  {
    if (podFandocFile == null) return
    podFandocFile.out.writeChars(applyTemplate(`pod.fandoc.template`, headerApply)).close
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** If 'out/fan/' exists, check if it contains any Fantom source files
  private Bool containsFcode()
  {
    fcode := false
    out.plus(`fan/`).walk
    {
      if ("fan" == it.ext) fcode = true
    }
    return fcode
  }

  private Bool isHx() { libOrg == "hx" }
  private Bool isResource() { type == "resource" }
  private Bool isConn() { type == "conn" }
  private Bool isFan() { type == "fantom" || isConn }

  private Str applyTemplate(Uri uri, |Str->Str?|? resolve := null)
  {
    util::Macro(template(uri)).apply |key->Str|
    {
      // check standard macros first
      val := stdMacros[key]
      if (val != null) return val

      if (resolve != null) val = resolve(key)
      if (val != null) return val

      throw Err("Unexpected key: $key")
    }
  }

  private Str template(Uri uri)
  {
    typeof.pod.file(`/lib/stub/`.plus(uri)).readAllStr
  }

  private Bool promptConfirm(Str msg)
  {
    res := Env.cur.prompt("$msg (Yn): ").trimToNull ?: "y"
    return res.lower == "y"
  }

  ** Prompt for a value and trim
  private Str prompt(Str msg) { Env.cur.prompt("${msg}: ").trim }

  ** Prompt for a value or return the default of nothing specified
  private Str promptDef(Str msg, Str def) { Env.cur.prompt("${msg} [$def]: ").trimToNull ?: def }


}