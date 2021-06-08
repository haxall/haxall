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
    this.inputs = rt.libs.list.map |lib->LibInput| { HxdLibInput(lib) }
    this.inputs.add(DbLibInput(rt))
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

  override MDef createDef(BDef b) { FuncDef(b) }

  override Err createUnknownErr(Str name) { UnknownFuncErr(name) }
}

**************************************************************************
** FuncDef
**************************************************************************

const class FuncDef : MDef
{
  new make(BDef b) : super(b) { exprRef.val = b.aux }

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
    src := get("src") as Str ?: throw Err("Func missing src: $this")
    return Parser(Loc(lib.name + "::" +  name), src.in).parseTop(name)
  }

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
    this.funcsRef = AtomicRef(lib.funcs)
  }

  const Str name
  const HxLib lib
  const HxdLibSpi spi
  const override CLoc loc
  const HxdInstalledLib install
  const File metaFile
  const AtomicRef funcsRef
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
      file.ext == "trio" && file.name != "lib.trio" && file.pathStr.startsWith(libDir)
    }
  }

  override ReflectInput[] scanReflects(DefCompiler c)
  {
    // check for FooLib.funcs override
    typeName := install.meta["typeName"] as Str
    if (typeName != null)
    {
      // we bind to the actual instance later once HxLibs are constructed
      funcsSlot := Type.find(typeName).slot("funcs")
      funcsType := funcsSlot is Field ? ((Field)funcsSlot).type : ((Method)funcsSlot).returns
      if (funcsType != HxLibFuncs#)
      {
        return [FuncMethodsReflectInput(funcsType, funcsRef)]
      }
    }

    // axon uses CoreLib
    if (name == "axon")
    {
      return [FuncMethodsReflectInput(pod.type("CoreLib"), null)]
    }

    // none
    return ReflectInput#.emptyList
  }
}

**************************************************************************
** DbLibInput
**************************************************************************

internal const class DbLibInput : LibInput
{
  new make(HxdRuntime rt) { this.rt = rt; this.loc = CLoc("db") }

  const HxdRuntime rt

  const override CLoc loc

  override Obj scanMeta(DefCompiler c)
  {
    symbol := Symbol("lib:hx_db")
    acc := Str:Obj[:]
    acc["def"] = symbol
    acc["baseUri"] = rt.httpUri + `/def/hx_db/`
    acc["version"] = rt.version.toStr
    acc["depends"] = rt.libs.list.map |lib->Symbol| { Symbol("lib:$lib.name") }
    return Etc.makeDict(acc)
  }

  override File[] scanFiles(DefCompiler c)
  {
    File[,]
  }

  override Dict[] scanExtra(DefCompiler c)
  {
    rt.db.readAllList("def")
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




