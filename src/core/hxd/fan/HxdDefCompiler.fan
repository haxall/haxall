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
  new make(Folio db, Log log)
  {
    this.db = db
    this.log = log
    this.factory = HxdDefFactory()
  }

  const Folio db

  ** Utility to read the lib.trio meta Dict for given name since
  ** this runtime doesn't load it into the namespace if not enabled.
  ** Note: this dict is not exactly the same as the namespace Lib dict
  ** because no normalization is performed for baseUri, version, etc
  Dict readLibMeta(Str libName)
  {
    readStep := ReadLibMeta(this, libName)
    run([InitLibNameToPod(this), readStep])
    return readStep.libMeta
  }

  override DefCompilerStep[] frontend()
  {
    super.frontend.insertAll(0, [
      InitLibNameToPod(this),
      InitInputs(this)
    ])
  }

  internal Pod libNameToPod(Str name)
  {
    libNameToPodMap[name] ?: throw Err("No pod indexed for $name.toCode")
  }

  internal File libNameToMetaFile(Str name)
  {
    pod := libNameToPod(name)
    file := pod.file(`/lib/lib.trio`, false)
    if (file == null) file = pod.file(`/lib/${name}/lib.trio`, false)
    if (file == null) throw Err("Pod missing /lib/lib.trio: $pod.name.toCode")
    return file
  }

  internal [Str:Pod]? libNameToPodMap     // InitLibNameToPod
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
** InitLibNameToPod
**************************************************************************

internal class InitLibNameToPod : DefCompilerStep
{
  new make(HxdDefCompiler c) : super(c) {}

  override Void run()
  {
    c := (HxdDefCompiler)compiler
    acc := Str:Pod[:]

    // iterator all pods which declare ph.lib in their index
    Env.cur.indexPodNames("ph.lib").each |podName|
    {
      try
        mapPod(acc, podName)
      catch (Err e)
        err("Invalid pod ph.lib index", CLoc(podName), e)
    }

    // init compiler field
    c.libNameToPodMap = acc
  }

  private Void mapPod(Str:Pod acc, Str podName)
  {
    // load pod
    pod := Pod.find(podName)

    // parse index.props
    index := pod.file(`/index.props`).in.readPropsListVals

    // get the list of values for "ph.lib" key
    libNames := index["ph.lib"]
    libNames.each |n|
    {
      dup := acc[n]
      if (dup != null)
        err2("Duplicate ph.lib index for $n.toCode", CLoc(dup.name), CLoc(pod.name))
      else
        acc[n] = pod
    }
  }
}

**************************************************************************
** ReadLibMeta
**************************************************************************

internal class ReadLibMeta : DefCompilerStep
{
  new make(HxdDefCompiler c, Str libName) : super(c) { this.libName  = libName }

  override Void run()
  {
    // note: this is just a straight read of the "lib.trio"; it does
    // not perform any normalization such as baseUri, version, etc
    c := (HxdDefCompiler)compiler
    file := c.libNameToMetaFile(libName)
    this.libMeta = TrioReader(file.in).readDict
  }

  const Str libName
  Dict? libMeta
}

**************************************************************************
** InitInputs
**************************************************************************

internal class InitInputs : DefCompilerStep
{
  new make(HxdDefCompiler c) : super(c) {}

  override Void run()
  {
    c := (HxdDefCompiler)compiler
    acc := LibInput[,]

    // create LibInput for each hxLib record in database
    c.db.readAllList("hxLib").each |rec|
    {
      name := rec["hxLib"] as Str
      if (name == null) return

      try
        acc.add(initInput(c, name, rec))
      catch (Err e)
        err("Cannot init hxLib", CLoc(name), e)
    }

    c.inputs = acc
  }

  private LibInput initInput(HxdDefCompiler c, Str name, Dict rec)
  {
    pod := c.libNameToPod(name)
    libFile := c.libNameToMetaFile(name)
    return HxdLibInput(name, pod, libFile)
  }
}

**************************************************************************
** HxdLibInput
**************************************************************************

internal const class HxdLibInput : LibInput
{
  new make(Str name, Pod pod, File libFile)
  {
    this.name = name
    this.pod = pod
    this.libFile = libFile
    this.loc = CLoc(libFile)
  }

  const Str name
  const Pod pod
  const File libFile

  Dict meta() { metaRef.val as Dict ?: throw Err("no meta") }
  const AtomicRef metaRef := AtomicRef()  // after scanMeta

  const override CLoc loc

  override Obj scanMeta(DefCompiler c)
  {
    meta := parseLibMetaFile(c, libFile)
    if (meta is Dict)
    {
      acc := Etc.dictToMap(meta)
      sym := acc["def"] as Symbol ?: throw c.err("Missing 'def' symbol", loc)
      if (sym.toStr != "lib:$name") throw c.err("Mismatched 'def' for lib.trio: $sym != lib:$name", loc)
      inferMeta(acc)
      meta = Etc.makeDict(acc)
      metaRef.val = meta
    }
    return meta
  }

  private Void inferMeta(Str:Obj acc)
  {
    // infer version tag
    if (acc["version"] == null)
      acc["version"] = pod.version.toStr

    // infer baseUri tag
    if (acc["baseUri"] == null)
      acc["baseUri"] = (pod.meta["proj.uri"] ?: "http://localhost/").toUri + `/def/${name}/`
  }

  override File[] scanFiles(DefCompiler c)
  {
    libDir := "/" + libFile.path[0..-2].join("/") + "/"
    return pod.files.findAll |file|
    {
      file.ext == "trio" && file.name != "lib.trio" && file.pathStr.startsWith(libDir)
    }
  }

  override ReflectInput[] scanReflects(DefCompiler c)
  {
    // check for FooLib.funcs override
    typeName := meta["typeName"] as Str
    if (typeName != null)
    {
      // we bind to the actual instance later once HxLibs are constructed
      funcsSlot := Type.find(typeName).slot("funcs")
      funcsType := funcsSlot is Field ? ((Field)funcsSlot).type : ((Method)funcsSlot).returns
      if (funcsType != HxLibFuncs#)
      {
        // TODO
        libRef := AtomicRef(null)
        // ((HxdDefCompiler)c).funcLibRefs.add(name, libRef)
        return [FuncMethodsReflectInput(funcsType, libRef)]
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




