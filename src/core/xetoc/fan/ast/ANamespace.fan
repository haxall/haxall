//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Nov 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** AST namesapce
**
internal class ANamespace : CNamespace
{
  new make(Init step)
  {
    this.compiler = step.compiler
    this.ns = step.ns
  }

  CSpec? metaSpec(Str name, FileLoc loc)
  {
    top(metaSpecs, name, SpecFlavor.meta, loc)
  }

  CSpec? global(Str name, FileLoc loc)
  {
    top(globals, name, SpecFlavor.global, loc)
  }

  private CSpec? top(Str:Obj acc, Str name, SpecFlavor flavor, FileLoc loc)
  {
    g := acc[name]
    if (g != null) return g as CSpec
    g = findTop(name, flavor, loc)
    acc[name] = g ?: "not-found"
    return g as CSpec
  }

  private CSpec? findTop(Str name, SpecFlavor flavor, FileLoc loc)
  {
    // walk thru my lib and dependencies
    acc := CSpec[,]

    // check my own lib
    mine := compiler.lib?.tops?.get(name)
    if (mine != null && mine.flavor === flavor) acc.add(mine)

    // check my dependencies
    compiler.depends.libs.each |lib|
    {
      g := lib.spec(name, false)
      if (g != null && g.flavor === flavor) acc.add((CSpec)g)
    }

    // no global slots by this name
    if (acc.isEmpty) return null

    // exactly one
    if (acc.size == 1) return acc.first

    // duplicate global slots with this name
    compiler.err("Duplicate $flavor specs: " + acc.join(", "), loc)
    return null
  }

  override Void eachSubtype(CSpec type, |CSpec| f)
  {
    // iterate types from imported namespace only
    // if base type is not in the AST being compiled
    if (ns != null && type is XetoSpec) ns.eachSubtype(type, f)

    // iterate my own types
    if (compiler.lib != null)
    {
      compiler.lib.tops.each |x|
      {
        if (x.isType && x.cisa(type)) f(x)
      }
    }
  }

  const MNamespace? ns
  XetoCompiler compiler
  Str:Obj metaSpecs := [:]
  Str:Obj globals := [:]
}

