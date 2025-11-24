//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** AST namespace
**
@Js
internal class ANamespace : CNamespace
{
  new make(Init step)
  {
    this.compiler = step.compiler
    this.ns = step.ns
  }

  private Spec? top(Str:Obj acc, Str name, SpecFlavor flavor, FileLoc loc)
  {
    g := acc[name]
    if (g != null) return g
    g = findTop(name, flavor, loc)
    acc[name] = g ?: "not-found"
    return g
  }

  private Spec? findTop(Str name, SpecFlavor flavor, FileLoc loc)
  {
    // walk thru my lib and dependencies
    acc := Spec[,]

    // check my own lib
    mine := compiler.lib?.tops?.get(name)
    if (mine != null && mine.flavor === flavor && isTop(mine)) acc.add(mine)

    // check my dependencies
    compiler.depends.libs.each |lib|
    {
      g := lib.spec(name, false)
      if (g != null && g.flavor === flavor && isTop(g)) acc.add(g)
    }

    // no global slots by this name
    if (acc.isEmpty) return null

    // exactly one
    if (acc.size == 1) return acc.first

    // duplicate global slots with this name
    compiler.err("Duplicate $flavor specs: " + acc.join(", "), loc)
    return null
  }

  private Bool isTop(Spec s)
  {
    // we don't have the isFunc flag in AST yet...
    if (!s.isAst && s.isFunc) return false
    return true
  }

  override Void eachTypeThatIs(Spec type, |Spec| f)
  {
    // iterate types from imported namespace only
    // if base type is not in the AST being compiled
    if (ns != null && type is XetoSpec)
    {
      // we can only iterate libs that have been loaded already - we don't
      // want to try to force a load of the lib currently being compiled
      // or any depends further upstream; we should be able to safely say
      // that in order to get this point all the dependent libs are loaded
      typeSpec := (XetoSpec)type
      ns.versions.each |v|
      {
        lib := ns.lib(v.name, false)
        if (lib != null)
        {
          lib.types.each |x|
          {
            if (x.isa(typeSpec)) f(x)
          }
        }
      }
    }

    // iterate my own types
    if (compiler.lib != null)
    {
      compiler.lib.tops.each |x|
      {
        if (x.isType && x.isa(type)) f(x)
      }
    }
  }

  const MNamespace? ns
  MXetoCompiler compiler
  Str:Obj metaSpecs := [:]
}

