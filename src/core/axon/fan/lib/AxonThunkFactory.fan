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
    fn := loadThunkFantom(spec, meta, pod)
    if (fn != null) return fn

    // check axon source
    code := spec.meta["axon"] as Str
    if (code  != null) return parseAxon(spec, meta, code)

    // try compTree xeto source
    comp := spec.meta["compTree"] as Str
    if (comp != null) return parseComp(spec, meta, comp)

    // check for template
    if (spec.func.isTemplate) return TemplateFn(spec, meta, toParams(spec))

    throw UnsupportedErr("Cannot resolve thunk: $spec [pod:$pod]")
  }

//////////////////////////////////////////////////////////////////////////
// Fantom
//////////////////////////////////////////////////////////////////////////

  private TopFn? loadThunkFantom(Spec spec, Dict meta, Pod? pod)
  {
    if (pod == null) return null

    // resolve fantom type BaseFuncs where base is spec name
    // of the libExt otherwise the last name of the dotted lib name
    lib := spec.lib
    base := thunkFantomBaseName(lib)
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

  private Str thunkFantomBaseName(Lib lib)
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

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  private TopFn? parseAxon(Spec spec, Dict meta, Str src)
  {
    /*
    // wrap src with parameterized list
    s := StrBuf(src.size + 256)
    s.addChar('(')
    spec.func.params.each |p, i|
    {
      if (i > 0) s.addChar(',')
      s.add(p.name)
    }
    s.add(")=>do\n")
    s.add(src)
    s.add("\nend")
    */

    qname := meta->qname
    return Parser(Loc(qname), src.in).parseTop(spec.name, meta)
  }

  private TopFn? parseComp(Spec spec, Dict meta, Str src)
  {
    params := spec.func.params.map |p->FnParam| { FnParam(p.name) }
    return CompFn(spec.name, meta, params, src)
  }

  private FnParam[] toParams(Spec spec)
  {
    spec.func.params.map |p->FnParam| { FnParam(p.name) }
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
}

