//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Feb 2025  Brian Frank  Creation
//

using xeto

**
** XetoPlugin is used to plug-in Axon functionality into the Xeto environment
**
@Js @NoDoc
const class XetoPlugin : XetoAxonPlugin
{
  new make()
  {
    // init Xeto lib => Fantom qname bindings
    bindings := Str:Str[:]
    Env.cur.index("axon.bindings").each |str|
    {
      try
      {
        toks := str.split
        libName := toks[0]
        type := toks[1]
        bindings.set(libName, type)
      }
      catch (Err e) echo("ERR: Cannot init axon.binding: $str\n  $e")
    }
    this.bindings = bindings
  }

  override Fn? parse(Spec spec)
  {
    // first try axon source
    meta := spec.meta
    src := meta["axon"] as Str
    if (src != null) return parseAxon(spec, meta, src)

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

  const Str:Str bindings
}

