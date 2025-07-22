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

**
** AxonThunkFactory creates xeto func thunks which are also Axon functions
**
@Js @NoDoc
const class AxonThunkFactory : ThunkFactory
{

  override Thunk create(Spec spec, Pod? pod)
  {
    // check for fantom method thunk
    thunk := loadThunkFantom(spec, pod)
    if (thunk != null) return thunk

    // check for axon
    axon := spec.meta["axon"] as Str
    if (axon != null) throw Err("Axon parse")

    throw UnsupportedErr("No funcs registered for pod: $pod.name")
  }

  private Thunk? loadThunkFantom(Spec spec, Pod? pod)
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
    funcName := spec.name
    if (lib.name == "axon")
    {
      if (funcName == "toStr" || funcName == "as" || funcName == "is" ||
          funcName == "equals" || funcName == "trap")
        funcName = "_" + funcName
    }
    method := type.method(funcName, false)
    if (method == null) return null

    // verify method has facet
    if (!method.hasFacet(Api#)) throw Err("Method missing @Api facet: $method.qname")
    return FantomFn.reflectMethod(method, funcName, spec.meta, null)
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

/*
  override Fn? parse(Spec spec)
  {
    // first try axon source
    meta := spec.meta
    code := meta["axon"] as Str
    if (code  != null) return parseAxon(spec, meta, code)

    // second try axonComp xeto source
    comp := meta["axonComp"] as Str
    if (comp != null) return parseComp(spec, meta, comp)

    // next try to Fantom reflection
    fantom := bindings[spec.lib.name]
    if (fantom != null) return reflectFantom(spec, meta, fantom)

    // no joy
    return null
  }

  private Fn? parseAxon(Spec spec, Dict meta, Str src)
  {
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

    return Parser(Loc(spec.qname), s.toStr.in).parseTop(spec.name, meta)
  }

  private Fn? parseComp(Spec spec, Dict meta, Str src)
  {
    return CompFn(spec.name, meta, toParams(spec), src)
  }

  private Fn? reflectFantom(Spec spec, Dict meta, Str qname)
  {
    // resolve type from bindings
    type := Type.find(qname)

    // lookup method
    name := spec.name
    method := type.method(name, false)
    if (method == null) method = type.method("_" + name, false)
    if (method == null) return null

    // verify method is static and has axon facet
    if (!method.hasFacet(Axon#)) return null

    return FantomFn.reflectMethod(method, name, meta, null)
  }

  private FnParam[] toParams(Spec spec)
  {
    spec.func.params.map |p->FnParam| { FnParam(p.name) }
  }

*/
}

