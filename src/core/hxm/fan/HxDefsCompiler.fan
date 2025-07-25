//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//   12 Jul 2025  Brian Frank  Redesign for 4.0
//

using concurrent
using xeto
using haystack
using axon
using folio
using hx
using def
using defc

**
** Haxall default implementation of definition compiler
**
class HxDefCompiler : DefCompiler
{
  new make(Proj proj)
  {
    this.log     = proj.log
    this.factory = ProjDefFactory()
    this.inputs  = buildInputs(proj)
  }

  internal ProjLibInput[] buildInputs(Proj proj)
  {
    acc := Str:ProjLibInput[:]

    // include base def libs
    "ph,phScience,phIoT,phIct,hx,obs,axon".split(',').each |name|
    {
      pod  := Pod.find(name)
      meta := podToMeta(pod)
      acc.add(name, ProjLibInput(name, pod, meta))
    }

    // map xeto libs to def pods
    proj.ns.libs.each |lib|
    {
      if (acc[lib.name] != null) return
      input := xetoToInput(proj, lib)
      if (input != null && acc[input.name] == null)
        acc[input.name] = input
    }

    return acc.vals
  }

  internal ProjLibInput? xetoToInput(Proj proj, Lib lib)
  {
    try
    {
      pod := xetoToPod(lib.name)
      if (pod == null)
      {
        // kind of hacky, but need to wire up defs until conn fw reworked
        if (lib.name == "hx.test.conn")
           pod = Pod.find("testHx")
        else
          return null
      }

      meta := podToMeta(pod)
      def := meta->def.toStr["lib:".size..-1]
      return ProjLibInput(def, pod, meta)
    }
    catch (Err e)
    {
      log.err("Cannot map xeto lib to defs [$lib]", e)
      return null
    }
  }

  Pod? xetoToPod(Str n)
  {
    if (n.startsWith("hx."))
    {
      hxName := "hx" + n[3..-1].capitalize
      pod := Pod.find(hxName, false)
      if (pod != null) return pod
    }

    return null
  }

  Dict? podToMeta(Pod pod)
  {
    // check for lib.trio meta file
    libFile := pod.file(`/lib/lib.trio`, false)
    if (libFile == null)
    {
      echo("WARN: no lib.trio found in pod [$pod.name]")
      return null
    }

    meta := CompilerInput.parseLibMetaFile(this, libFile) as Dict
    if (meta != null)
    {
      symbol := (Symbol)meta->def
      if (meta.missing("version")) meta = Etc.dictSet(meta, "version", pod.version.toStr)
      if (meta.missing("baseUri")) meta = Etc.dictSet(meta, "baseUri", `/def/$symbol.name`)
    }
    return meta
  }
}

**************************************************************************
** HxDefOverlayCompiler
**************************************************************************

const class HxDefOverlayCompiler
{
  new make(HxProj proj, DefNamespace base)
  {
    this.proj = proj
    this.base = base
    this.log  = proj.log
    this.libSymbol = Symbol("lib:proj")
  }

  const HxProj proj
  const DefNamespace base
  const Log log
  const Symbol libSymbol

  DefNamespace compileNamespace()
  {
    acc := Str:Obj[:]
    acc["def"] = libSymbol
    acc["baseUri"] = `/def/$libSymbol.name/`
    acc["version"] = proj.sys.info.version.toStr
    meta := Etc.makeDict(acc)

    b := BOverlayLib(base, meta)
    proj.db.readAll(Filter.has("def")).each |rec| { addRecDef(b, rec) }

    return MOverlayNamespace(base, MOverlayLib(b), |DefLib lib->Bool| { true })
  }

  private Void addRecDef(BOverlayLib b, Dict rec)
  {
    // parse symbol from def tag
    symbol := rec["def"] as Symbol
    if (symbol == null) return err("Invalid def symbol '${rec->def}'", rec)
    try
    {

      // verif dups
      if (b.isDup(symbol.toStr)) return err("Duplicate defs '$symbol.toCode'", rec)

      // normalize rec with implied def tags
      acc := Str:Obj?[:]
      rec.each |v, n| { acc[n] = v }
      acc["def"] = symbol
      acc["lib"] = libSymbol
      norm := Etc.makeDict(acc)

      // check override
      if (checkOverrideErr(symbol.toStr, rec)) return

      // add to overlay lib
      b.addDef(norm)
    }
    catch (Err e) err("Invalid proj rec def '$symbol'", rec, e)
  }

  private Bool checkOverrideErr(Str symbol, Dict rec)
  {
    // lookup func from installed
    x := base.def(symbol, false)
    if (x == null) return false

    // if function explicitly marked overridable its ok
    if (x.has("overridable")) return false

    // this is an error!
    err("Cannot override ${symbol} from ${x.lib}", rec)
    return true
  }

  private Void err(Str msg, Dict rec, Err? err := null)
  {
    log.err("$msg [$rec.id.toCode]", err)
  }
}

**************************************************************************
** ProjDefFactory
**************************************************************************

internal const class ProjDefFactory : DefFactory
{
  override MFeature createFeature(BFeature b)
  {
    switch (b.name)
    {
      case "func": return FuncFeature(b)
      default:     return super.createFeature(b)
    }
  }
}

**************************************************************************
** FuncFeature
**************************************************************************

internal const class FuncFeature : MFeature
{
  new make(BFeature b) : super(b) {}

  override Type defType() { FuncDef# }

  override MDef createDef(BDef b)
  {
    src := b.meta["src"] as Str
    if (src != null && b.meta.has("nosrc"))
      b = BDef(b.symbol, b.libRef, Etc.dictRemove(b.meta, "src"), b.aux)
    return FuncDef(b, src)
  }

  override Err createUnknownErr(Str name) { UnknownFuncErr(name) }
}

**************************************************************************
** FuncDef
**************************************************************************

const class FuncDef : MDef
{
  new make(BDef b, Str? src) : super(b)
  {
    this.src = src
    this.exprRef.val = b.aux
  }

  Fn expr()
  {
    // Fantom funcs are passed in via BDef.aux, but Axon
    // funcs are lazily parsed and cached
    fn := exprRef.val
    if (fn == null) exprRef.val = fn = parseExpr
    return fn
  }

  private Fn parseExpr()
  {
    if (src == null) throw Err("Func missing src: $this")
    return Parser(Loc(lib.name + "::" +  name), src.in).parseTop(name, this)
  }

  private const Str? src
  private const AtomicRef exprRef := AtomicRef()
}

**************************************************************************
** ProjLibInput
**************************************************************************

internal const class ProjLibInput : LibInput
{
  new make(Str name, Pod pod, Dict meta)
  {
    this.name = name
    this.pod  = pod
    this.meta = meta
    this.loc  = CLoc(pod.name)
  }

  const Str name
  const Pod pod
  const Dict meta
  const override CLoc loc

  override Obj scanMeta(DefCompiler c)
  {
    meta
  }

  override File[] scanFiles(DefCompiler c)
  {
    return pod.files.findAll |file|
    {
      if (file.ext != "trio") return false
      if (file.name == "lib.trio") return false
      if (!isUnderLibDir(file)) return false
      if (file.name == "skyarc.trio" && name != "hx") return false
      return true
    }
  }

  private Bool isUnderLibDir(File file)
  {
    // allow lib/xxx.trio or lib/{name}/xxx.trio
    path := file.uri.path
    if (path.size != 2 && path.size != 3) return false
    if (path[0] != "lib") return false
    if (path.size == 3 && path[1] != name) return false
    return true
  }

  override ReflectInput[] scanReflects(DefCompiler c)
  {
    // check for FooLib -> FooFuncs class
    typeName := meta["typeName"] as Str
    if (typeName != null)
    {
      funcsType := Type.find(typeName[0..-4]+"Funcs", false)
      if (funcsType != null)
        return [FuncMethodsReflectInput(funcsType, null)]
    }

    // specials
    if (name == "axon") return [FuncMethodsReflectInput(AxonFuncs#, null)]
    if (name == "hx") return [FuncMethodsReflectInput(HxFuncs#, null)]

    // none
    return ReflectInput#.emptyList
  }
}

**************************************************************************
** FuncReflectInput
**************************************************************************

internal abstract const class FuncReflectInput : ReflectInput
{
  new make(Type type, AtomicRef? instanceRef)
  {
    this.type = type
    this.instanceRef = instanceRef
  }

  override const Type type

  const AtomicRef? instanceRef

  override Str toStr() { "$typeof $type" }

  override Void addMeta(Symbol symbol, Str:Obj acc)
  {
    acc["func"] = Marker.val
    acc["name"] = symbol.name
  }
}

** FuncMethodsReflectInput reflects methods in FooFuncs class
internal const class FuncMethodsReflectInput : FuncReflectInput
{
  new make(Type type, AtomicRef? instanceRef) : super(type, instanceRef) {}

  override Type? methodFacet() { Axon# }

  override Symbol toSymbol(Slot? slot) { Symbol("func:" + FantomFn.toName(slot)) }

  override Void onDef(Slot? slot, CDef def)
  {
    def.aux = FantomFn.reflectMethod(slot, def.name, def.declared, instanceRef)
  }
}

**************************************************************************
** ProjOverlayLib
**************************************************************************

const class ProjOverlayLib
{
  new make(Proj proj, DefNamespace base)
  {
    this.proj      = proj
    this.base      = base
    this.log       = proj.log
    this.libSymbol = Symbol("lib:hx_db")
  }

  const Proj proj
  const DefNamespace base
  const Log log
  const Symbol libSymbol

  DefNamespace compileNamespace()
  {
    sys := proj.sys
    acc := Str:Obj[:]
    acc["def"] = libSymbol
    acc["baseUri"] = sys.http.siteUri + `def/hx_db/`
    acc["version"] = sys.info.version.toStr
    meta := Etc.makeDict(acc)

    b := BOverlayLib(base, meta)
    proj.db.readAll(Filter.has("def")).each |rec| { addRecDef(b, rec) }

    return MOverlayNamespace(base, MOverlayLib(b), |DefLib lib->Bool| { true })
  }

  private Void addRecDef(BOverlayLib b, Dict rec)
  {
    // parse symbol from def tag
    symbol := rec["def"] as Symbol
    if (symbol == null) return err("Invalid def symbol '${rec->def}'", rec)
    try
    {

      // verif dups
      if (b.isDup(symbol.toStr)) return err("Duplicate defs '$symbol.toCode'", rec)

      // normalize rec with implied def tags
      acc := Str:Obj?[:]
      rec.each |v, n| { acc[n] = v }
      acc["def"] = symbol
      acc["lib"] = libSymbol
      norm := Etc.makeDict(acc)

      // check override
      if (checkOverrideErr(symbol.toStr, rec)) return

      // add to overlay lib
      b.addDef(norm)
    }
    catch (Err e) err("Invalid proj rec def '$symbol'", rec, e)
  }

  private Bool checkOverrideErr(Str symbol, Dict rec)
  {
    // lookup func from installed
    x := base.def(symbol, false)
    if (x == null) return false

    // if function explicitly marked overridable its ok
    if (x.has("overridable")) return false

    // this is an error!
    err("Cannot override ${symbol} from ${x.lib}", rec)
    return true
  }

  private Void err(Str msg, Dict rec, Err? err := null)
  {
    log.err("$msg [$rec.id.toCode]", err)
  }
}

