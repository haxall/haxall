//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Feb 2025  Brian Frank  Creation
//   22 Jul 2025  Brian Frank  Garden City (redesign)
//

using concurrent
using xeto
using xetom
using haystack

**
** AxonThunkFactory creates xeto func thunks which are also Axon functions
**
@Js @NoDoc
const class AxonThunkFactory : ThunkFactory
{

  override Thunk create(Spec spec, Pod? pod)
  {
    fn := doCreate(spec, pod)
    TopFn#qname->setConst(fn, spec.lib.name + "::" + spec.name)
    return fn
  }

  private TopFn doCreate(Spec spec, Pod? pod)
  {
    // convert spec meta to TopFn meta we use for reflection in func()
    meta := specToFnMeta(spec)

    // check for fantom method thunk
    fn := loadFantom(spec, meta, pod)
    if (fn != null) return fn

    // check axon source
    code := spec.meta["axon"] as Str
    if (code  != null) return parseAxon(spec, meta, code)

    // try compTree xeto source
    comp := spec.meta["compTree"] as Str
    if (comp != null) return parseCompTree(spec, meta, comp)

    // check for template
    if (spec.func.isTemplate) return TemplateFn(spec, meta, toParams(meta->qname, spec))

    throw UnsupportedErr("Cannot resolve thunk: $spec [pod:$pod]")
  }

//////////////////////////////////////////////////////////////////////////
// Fantom
//////////////////////////////////////////////////////////////////////////

  private TopFn? loadFantom(Spec spec, Dict meta, Pod? pod)
  {
    if (pod == null) return null

    // check for component method
    if (spec.parent != null && spec.parent.isComp) return loadFantomCompMethod(spec, meta, pod)

    // resolve fantom type BaseFuncs where base is spec name
    // of the libExt otherwise the last name of the dotted lib name
    lib := spec.lib
    base := fantomBaseName(lib)
    typeName := base + "Funcs"
    type := pod.type(typeName, false)
    // echo("~~> $spec.lib base=$base -> $typeName -> $type")
    if (type == null) return null

    // method name is same as func; special cases handled with _name
    methodName := spec.name
    if (lib.name == "axon")
    {
      n := methodName
      if (n == "toStr" || n == "as" || n == "is" || n == "equals" || n == "trap" || n == "echo")
        methodName = "_" + n
    }
    method := type.method(methodName, false)
    if (method == null) return null

    // verify method has facet
    if (!method.hasFacet(Api#)) throw Err("Method missing @Api facet: $method.qname")
    return FantomFn.reflectMethod(method, spec.name, meta)
  }

  private Str fantomBaseName(Lib lib)
  {
    // resolve fantom type BaseFuncs where base is spec name
    // of the libExt otherwise the last name of the dotted lib name
    libExt := lib.meta["libExt"]?.toStr
    if (libExt != null)
    {
       name := XetoUtil.qnameToName(libExt)
       if (name.endsWith("Ext")) name = name[0..-4]
       return name
    }
    else
    {
      return XetoUtil.lastDottedName(lib.name).capitalize
    }
  }

  private TopFn? loadFantomCompMethod(Spec spec, Dict meta, Pod? pod)
  {
    // map to fantom type
    type := pod.type(spec.parent.name, false)
    if (type == null) return null

    // map foo to method onFoo
    n := spec.name
    methodName := StrBuf(n.size + 1).add("on").addChar(n[0].upper).addRange(n, 1..-1).toStr
    method := type.method(methodName, false)
    if (method == null) return null

    // must have @Api facet, be non-static, and have one arg
    func := spec.func
    p := method.params.first
    if (!method.hasFacet(Api#))  throw Err("Comp method missing @Api facet: $method.qname")
    if (method.isStatic)         throw Err("Comp method must not be static: $method.qname")
    if (func.params.size != 1)   throw Err("Comp method must have exactly one param: $method.qname")
    if (method.params.size != 1) throw Err("Comp method must have exactly one param: $method.qname")

    return FantomFn.makeComp(spec, meta, [FnParam(func.params.first.name)], method)
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  private TopFn? parseAxon(Spec spec, Dict meta, Str src)
  {
    name   := spec.name
    qname  := meta->qname
    loc    := Loc(qname)
    params := toParams(qname, spec)
    body   := Parser(loc, src.in).expr
    return TopFn(loc, name, meta, params, body)
  }

  private TopFn? parseCompTree(Spec spec, Dict meta, Str src)
  {
    params := spec.func.params.map |p->FnParam| { FnParam(p.name) }
    return CompFn(spec.name, meta, params, src)
  }

  private FnParam[] toParams(Str qname, Spec spec)
  {
    spec.func.params.map |p->FnParam|
    {
      Expr? def := null
      defStr := p.meta["axon"] as Str
      if (defStr != null)
      {
        try
          def = Parser(Loc(qname), defStr.in).expr
        catch (Err e)
          throw ParseErr("Cannot parse func '$qname' param '$p.name': $defStr.toCode", e)
      }
      return FnParam(p.name, def)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  static Dict specToFnMeta(Spec spec)
  {
    acc := Str:Obj[:]
    spec.meta.each |v, n|
    {
      if (n == "axon" || n == "compTree") return
      acc[n] = v
    }
    acc["name"]  = spec.name
    acc["qname"] = spec.lib.name + "::" + spec.name
    return Etc.dictFromMap(acc)
  }

//////////////////////////////////////////////////////////////////////////
// I/O
//////////////////////////////////////////////////////////////////////////

  ** Hook for XetoIO.readAxon
  override Dict readAxon(Namespace ns, Str src, Dict opts)
  {
    XetoAxonReader(ns, src, opts).read
  }
}

