//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 May 2021  Brian Frank  Creation
//

using concurrent
using haystack
using axon
using folio
using hx
using def
using defc

**
** Haxall definition compiler
**
class HxdDefCompiler : DefCompiler
{
  new make(HxdRuntime rt)
  {
    this.rt = rt
    this.log = rt.log
    this.factory = HxdDefFactory()
    this.inputs = rt.libs.list.map |lib->HxdLibInput| { HxdLibInput(lib) }
  }

  const HxdRuntime rt
}

**************************************************************************
** HxdDefFactory
**************************************************************************

internal const class HxdDefFactory : DefFactory
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
    return Parser(Loc(lib.name + "::" +  name), src.in).parseTop(name)
  }

  private const Str? src
  private const AtomicRef exprRef := AtomicRef()
}

**************************************************************************
** HxdLibInput
**************************************************************************

internal const class HxdLibInput : LibInput
{
  new make(HxLib lib)
  {
    this.name     = lib.name
    this.lib      = lib
    this.spi      = lib.spi
    this.install  = spi.install
    this.metaFile = install.metaFile
    this.loc      = CLoc(spi.install.metaFile)
  }

  const Str name
  const HxLib lib
  const HxdLibSpi spi
  const override CLoc loc
  const HxdInstalledLib install
  const File metaFile
  Pod pod() { install.pod }

  override Obj scanMeta(DefCompiler c)
  {
    install.meta
  }

  override File[] scanFiles(DefCompiler c)
  {
    libDir := "/" + install.metaFile.path[0..-2].join("/") + "/"
    return pod.files.findAll |file|
    {
      if (file.ext != "trio") return false
      if (file.name == "lib.trio") return false
      if (!file.pathStr.startsWith(libDir)) return false
      if (file.name == "skyarc.trio" && name != "hx") return false
      return true
    }
  }

  override ReflectInput[] scanReflects(DefCompiler c)
  {
    // check for FooLib -> FooFuncs class
    typeName := install.meta["typeName"] as Str
    if (typeName != null)
    {
      funcsType := Type.find(typeName[0..-4]+"Funcs", false)
      if (funcsType != null)
        return [FuncMethodsReflectInput(funcsType, null)]
    }

    // specials
    if (name == "axon") return [FuncMethodsReflectInput(CoreLib#, null)]
    if (name == "hx") return [FuncMethodsReflectInput(HxCoreFuncs#, null)]

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

** FuncCompReflectInput reflects AbstractComp class to Axon component
/* TODO
internal const class FuncCompReflectInput : FuncReflectInput
{
  new make(Type type) : super(type, null) {}

  override Type? typeFacet() { Axon# }

  override Symbol toSymbol(Slot? slot) { Symbol("func:" + type.name.decapitalize) }

  override Void onDef(Slot? slot, CDef def)
  {
    def.aux = AbstractComp.reflect(type)
  }
}
*/

**************************************************************************
** HxdOverlayLib
**************************************************************************

const class HxdOverlayCompiler
{
  new make(HxdRuntime rt, Namespace base)
  {
    this.rt = rt
    this.base = base
    this.log = rt.log
    this.libSymbol = Symbol("lib:hx_db")
  }

  const HxdRuntime rt
  const Namespace base
  const Log log
  const Symbol libSymbol

  Namespace compileNamespace()
  {
    acc := Str:Obj[:]
    acc["def"] = libSymbol
    acc["baseUri"] = rt.http.siteUri + `def/hx_db/`
    acc["version"] = rt.version.toStr
    meta := Etc.makeDict(acc)

    b := BOverlayLib(base, meta)
    rt.db.readAll(Filter.has("def")).each |rec| { addRecDef(b, rec) }

    return MOverlayNamespace(base, MOverlayLib(b), |Lib lib->Bool| { true })
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
      acc := Str:Obj[:]
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




