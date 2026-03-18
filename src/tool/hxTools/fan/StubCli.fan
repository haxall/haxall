//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   09 Feb 2022  Matthew Giannini  Creation
//

using util
using xeto
using xetom
using haystack
using hx

internal class StubCli : HxCli
{

//////////////////////////////////////////////////////////////////////////
// Options
//////////////////////////////////////////////////////////////////////////

  @Opt { help = "Description" }
  Str? desc

  @Opt { help = "Author"; aliases=["a"] }
  Str? author

  @Opt { help = "Initialize with metadata from given pod's build.fan" }
  Str? meta

  @Opt { help = "Generate ext code in this directory (if -ext)" }
  File out := File(`./`)

  @Opt { help = "Xeto dir" }
  File xetoDir := Env.cur.workDir.plus(`src/xeto/`)

  @Opt { help = "Generate a Fantom extension with the given pod name" }
  Str? ext

  @Opt { help = "Generate the ext as a Connector (requires -ext)" }
  Bool conn

  @Opt { help = "Xeto library name to generate. Optional if -ext is given"; aliases=["xeto"] }
  Str? xetoLib

  @NoDoc @Opt
  Bool sf

  // @NoDoc @Opt { help = "Use defaults for a Haxall project"; aliases=["hx"] }
  Bool haxall

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Date today := Date.today

  ** Organization name
  private Str? org

  ** Organization website
  private Str? orgUri

  ** Project name
  private Str? proj

  ** Project uri
  private Str? projUri

  ** Version control name
  private Str? vcs

  ** URL where source code is hosted
  private Str? vcsUri

  ** Source code license
  private Str? lic

  ** Standard macros for use across generating all files
  private Str:Str stdMacros := [:]

//////////////////////////////////////////////////////////////////////////
// Files
//////////////////////////////////////////////////////////////////////////

  ** Get the directory for the generated xeto library
  private File xetoLibDir() { xetoDir.plus(`${xetoLib}/`) }

  private File? xetoLibFile
  private File? xetoFuncsFile
  private File? xetoDocFile

  private File? buildFile
  private File? extFile
  private File? fanFuncsFile
  private File? connDispatchFile

//////////////////////////////////////////////////////////////////////////
// Stub
//////////////////////////////////////////////////////////////////////////

  override Int usage(OutStream out := Env.cur.out)
  {
    c := super.usage(out)
    out.printLine
    out.printLine(
      """Examples:
           # Create a new Fantom ext (implies -xetoLib acme.foo)
           hx stub -ext acmeFoo

           # Create a new Connector with explicit Xeto lib name
           # Without -xetoLib the lib would default to acme.awesome.conn
           hx stub -ext acmeAwesomeConn -xetoLib acme.awesomeconn

           # Create a resource ext
           hx stub -xetoLib acme.resources
         """)
    return c
  }

  override Str name() { "stub" }

  override Str summary() { "Stub a new Xeto library" }

  override Int run()
  {
    try
    {
      init
      promptInput
      sanityChecks
      initMacros
      initFiles
      confirm
      genXeto
      genPod
      printLine("Done!")
      return 0
    }
    catch (StubErr err)
    {
      return fatal(err.msg)
    }
  }

  private Int fatal(Str msg)
  {
    printLine
    err(msg)
    printLine
    usage
    return 1
  }

//////////////////////////////////////////////////////////////////////////
// Initialization
//////////////////////////////////////////////////////////////////////////

  ** Initialization prior to input collection
  protected virtual Void init()
  {
    // init type
    if (ext == null && xetoLib == null) throw StubErr("Must specify -ext or -xetoLib")
    if (ext != null && xetoLib == null) xetoLib = XetoUtil.camelToDotted(ext)
    if (!XetoUtil.isLibName(xetoLib)) throw StubErr("Not a valid Xeto library name: ${xetoLib}")

    // check conn is an ext
    if (conn && ext == null) throw StubErr("Must specify -ext with -conn")

    // force haxall mode if lib name matches haxall prefix
    if (xetoLib.startsWith("hx.")) haxall = true

    if (haxall) initHaxall
    if (meta != null) initMeta
  }

  private Void initHaxall()
  {
    if (ext != null)
    {
      if (ext.size < 3 || !ext.startsWith("hx") || !ext[2].isUpper)
        throw StubErr("Invalid Haxall pod name: ${ext}")
    }
    if (!xetoLib.startsWith("hx."))
      throw StubErr("Haxall Xeto lib must start with 'hx.': ${xetoLib}")

    this.org     = sf ? "SkyFoundry" : null
    this.orgUri  = sf ? "https://skyfoundry.com/" : null
    this.proj    = "Haxall"
    this.projUri = "https://haxall.io"
    this.vcs     = "git"
    this.vcsUri  = "https://github.com/haxall/haxall"
    this.lic     = "AFL-3.0"
  }

  private Void initMeta()
  {
    pod := Pod.find(meta)
    this.org      = pod.meta["org.name"]
    this.orgUri   = pod.meta["org.uri"]
    this.proj     = pod.meta["proj.name"]
    this.projUri  = pod.meta["proj.uri"]
    this.vcs      = pod.meta["vcs.name"]
    this.vcsUri   = pod.meta["vcs.uri"]
    this.lic      = pod.meta["license.name"]
  }

  ** Prompt for user input
  protected virtual Void promptInput()
  {
    if (desc == null)   this.desc = prompt("Description of ext")
    if (author == null) this.author = prompt("Author").trimToNull
    if (org == null)    this.org = prompt("Organization name").trimToNull
    if (orgUri == null) this.orgUri = prompt("Organization URL")
    if (vcs == null)    this.vcs = promptDef("VCS name", "git")
    if (vcsUri == null) this.vcsUri = prompt("VCS URL")
    if (lic == null)    this.lic = promptDef("License Name", "AFL-3.0")
    if (ext != null)
    {
      if (proj == null)    this.proj = prompt("Project name")
      if (projUri == null) this.projUri = prompt("Project URL")
    }
  }

  ** All inputs have been collected. Validate the inputs and throw
  ** an error if generation should stop.
  protected virtual Void sanityChecks()
  {
    if (!xetoDir.isDir) throw StubErr("-xetoDir is not a directory: ${xetoDir}")
    if (org == null) throw StubErr("Must specify an organization")
    if (author == null) throw StubErr("Must specify an author")

    if (isResource) return

    // check ext name
    if (!Etc.isTagName(ext)) throw StubErr("Ext must be a valid tag name: ${ext}")
    if (ext.endsWith("Ext")) throw StubErr("Ext name must not end with 'Ext': ${ext}")
    idx := ext.chars.findIndex { it.isUpper }
    if (idx == null || idx == 0) throw StubErr("Ext name must start with lowercase prefix: ${ext}")
    if (haxall && idx != 2) throw StubErr("Invalid hx extension name: ${ext}")
  }

  ** Initialize macros for filling in templates
  protected virtual Void initMacros()
  {
    stdMacros["org"]         = this.org
    stdMacros["xetoLib"]     = this.xetoLib
    stdMacros["funcPrefix"]  = funcPrefix
    stdMacros["desc"]        = this.desc
    stdMacros["header"]      = applyTemplate(`header.template`, headerApply)
    if (isExt)
    {
      stdMacros["podName"]    = this.ext
      stdMacros["typePrefix"] = typePrefix
    }
  }

  private |Str->Str?| headerApply := |key->Str?| {
    switch (key)
    {
      case "year":    return today.year.toStr
      case "date":    return today.toLocale("DD MMM YYYY")
      case "org":     return this.org
      case "author":  return this.author
      case "license": return this.haxall
        ? "Licensed under the Academic Free License version 3.0"
        : this.lic
      default: return null
    }
  }

  private Void initFiles()
  {
    // xeto library
    xetoLibFile   = xetoLibDir.plus(`lib.xeto`)
    xetoFuncsFile = xetoLibDir.plus(`funcs.xeto`)
    xetoDocFile   = xetoLibDir.plus(`doc.md`)

    if (isResource) return

    // ext
    out          = out.normalize.uri.plusSlash.toFile.plus(`${ext}/`)
    buildFile    = out.plus(`build.fan`)
    extFile      = out.plus(`fan/${typePrefix}Ext.fan`)
    fanFuncsFile = out.plus(`fan/${typePrefix}Funcs.fan`)

    // conn
    if (conn)
    {
      connDispatchFile = out.plus(`fan/${typePrefix}Dispatch.fan`)
    }
  }

  private Void confirm()
  {
    if (isResource)
      printLine("=== Stub Xeto Resource Lib ${xetoLib.toCode} ===")
    else
    {
      type := conn ? "Conn" : "Ext"
      printLine("=== Stub ${ext.toCode} (${type}) ===")
    }

    printLine("Author:  $author")
    printLine("Summary: $desc")
    if (meta != null) printLine("Using defaults from pod meta: ${meta}")
    else if (haxall) printLine("Using Haxall defaults")
    printLine

    listGeneratedFiles
    if (!promptConfirm("Continue?")) throw StubErr("Cancelled")
  }

//////////////////////////////////////////////////////////////////////////
// Xeto Library
//////////////////////////////////////////////////////////////////////////

  private Void genXeto()
  {
    genXetoLib
    genXetoFuncs
    genXetoDoc
  }

  ** Write lib.xeto
  private Void genXetoLib()
  {
    hx      := this.haxall
    extType := "${typePrefix}Ext"

    xetoLibFile.out.writeChars(applyTemplate(`lib.xeto.template`) |key->Str?| {
      switch (key)
      {
        case "version":    return hx ? Str<|BuildVar "hx.version"|> : Str<|"1.0.0"|>
        case "ph.depend":  return Str<|BuildVar "ph.depend"|>
        case "hx.depend":  return Str<|BuildVar "hx.depend"|>
        case "bv-license": return hx ? Str<|BuildVar "hx.license"|> : this.lic.toCode
        case "bv-org":     return hx ? Str<|BuildVar "hx.org.dis"|> : this.org.toCode
        case "bv-orgUri":  return hx ? Str<|BuildVar "hx.org.uri"|> : this.orgUri.toCode
        case "bv-vcs":     return hx ? Str<|BuildVar "hx.vcs.type"|> : this.vcs.toCode
        case "bv-vcsUri":  return hx ? Str<|BuildVar "hx.vcs.uri"|> : this.vcsUri.toCode
        case "libExt":     return isExt ? "libExt: ${extType}" : ""
        case "connStart":  return conn ? "" : "/*"
        case "connEnd":    return conn ? "" : "*/"
      }
      if (key == "extSpec")
      {
        if (isResource) return ""
        if (conn) return "${extType}: ConnExt <connFeatures:{}>"
        return "${extType}: Ext"
      }
      return null
    }).close
  }

  ** Write funcs.xeto
  private Void genXetoFuncs()
  {
    xetoFuncsFile.out.writeChars(applyTemplate(`funcs.xeto.template`) |key->Str?| {
      if (key == "fantomFunc")
      {
        if (isResource) return ""
        return """  // Markdown documentation for this func. Returns a simple
                    // hello world message.
                    ${funcPrefix}Fantom: Func { returns: Str? }"""
      }
      return null
    }).close
  }

  ** Write doc.md
  private Void genXetoDoc()
  {
    xetoDocFile.out.writeChars(applyTemplate(`doc.md.template`) |key->Str?| {
      switch (key)
      {
        case "title": return xetoLib
        default: return headerApply(key)
      }
    }).close
  }

//////////////////////////////////////////////////////////////////////////
// Pod
//////////////////////////////////////////////////////////////////////////

  private Void genPod()
  {
    if (isResource) return
    genBuild
    genExt
    genFanFuncs
    genConnDispatch
  }

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

    // fantom
    depends.add("concurrent $fanVer")
           .add("inet $fanVer")
           .add("crypto $fanVer")

    // haxall
    depends.add("xeto $hxVer")
           .add("haystack $hxVer")
           .add("axon $hxVer")
           .add("folio $hxVer")
           .add("hx $hxVer")

    // connector
    if (conn) depends.add("hxConn $hxVer")

    // source directories
    srcDirs := Uri[`fan/`]

    // apply template
    content := applyTemplate(`build.fan.template`) |key->Str?|
    {
      switch (key)
      {
        case "desc":          return this.desc
        case "orgUri":        return this.orgUri
        case "proj":          return this.proj
        case "projUri":       return this.projUri
        case "lic":           return this.lic
        case "vcs":           return this.vcs
        case "vcsUri":        return this.vcsUri
        case "depends":       return buildList(depends)
        case "srcDirs":       return buildList(srcDirs)
        case "xeto.bindings": return xetoLib.toCode
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

  private Void genExt()
  {
    template := conn ? `extConn.fan.template` : `ext.fan.template`
    extFile.out.writeChars(applyTemplate(template)).close
  }

  private Void genFanFuncs()
  {
    fanFuncsFile.out.writeChars(applyTemplate(`funcs.fan.template`)).close
  }

  private Void genConnDispatch()
  {
    if (connDispatchFile == null) return
    connDispatchFile.out.writeChars(applyTemplate(`connDispatch.fan.template`)).close
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Get the default XetoEnv
  private once XetoEnv xetoEnv() { XetoEnv.cur }

  ** Prefix to use for axon funcs
  **     funcPrefix = "acme.foo" => acmeFoo
  **     funcPrefix = "hx.foo" => "foo"
  private Str funcPrefix()
  {
    if (haxall) return xetoLib["hx.".size..-1]
    return XetoUtil.dottedToCamel(xetoLib)
  }

  ** Prefix to use for Fantom types
  **     typePrefix = "acmeFoo" => "AcmeFoo"
  **     typePrefix = "hxFoo" => "Foo"
  private Str typePrefix()
  {
    if (haxall) return ext["hx".size..-1]
    return ext.capitalize
  }

  ** Is this a resource lib
  private Bool isResource() { ext == null && xetoLib != null }

  ** Is this an ext
  private Bool isExt() { !isResource }

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

  ** Iterate fields/methods of this type that ends with "File" and get their value.
  ** Display if the value is non-null
  private Void listGeneratedFiles()
  {
    printLine("Generate Files:")
    typeof.slots.each |slot|
    {
      if (!slot.name.endsWith("File")) return
      File? f
      if (slot.isMethod)
        f = ((Method)slot).call(this) as File
      else
        f = ((Field)slot).get(this) as File
      if (f == null) return
      s := "  ${slot.name.toDisplayName}:".padr(22)
      s += f.osPath
      if (f.exists) s += " (OVERWRITE!!!)"
      printLine(s)
    }
  }
}

internal const class StubErr : Err
{
  new make(Str msg := "", Err? cause := null) : super(msg, cause) { }
}
