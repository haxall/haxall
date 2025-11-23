//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//   3 Jul 2023  Brian Frank  Redesign the AST
//

using util
using xeto
using xetom

**
** AST library
**
@Js
internal const class ALib : ADoc
{
   ** Constructor
  new make(MXetoCompiler c, FileLoc loc, Str name)
  {
    this.loc      = loc
    this.astRef   = Unsafe(ALibState(c))
    this.name     = name
    this.isSys    = name == "sys"
    this.asm      = XetoLib()
  }

  ** File location
  override const FileLoc loc

  ** Compiler
  override MXetoCompiler compiler() { ast.compiler }

  ** Node type
  override ANodeType nodeType() { ANodeType.lib }

  ** Dotted library name
  const Str name

  ** Is this the core sys library
  const Bool isSys

  ** XetoLib instance - we backpatch the "m" field in Assemble step
  const override XetoLib asm

  ** Files support (set in Parse)
  LibFiles? files() { ast.files }

  ** From pragma (set in ProcessPragma)
  ADict? meta() { ast.meta }

  ** Flags
  Int flags() { ast.flags }

  ** Version parsed from pragma (set in ProcessPragma)
  Version? version() { ast.version }

  ** Instance data
  override Str:AInstance instances() { ast.instances }

  ** Top level specs
  Str:ASpec tops() { ast.tops }

  ** TODO
  ASpec? top(Str name) { tops.get(name) }

  ** Lookup type spec
  ASpec? type(Str name)
  {
    x := tops.get(name)
    if (x != null && x.isType) return x
    return null
  }

  ** List type specs ordered by inheritance (set in InheritSlots)
  ASpec[] types() { ast.types ?: throw NotReadyErr(name) }

  ** Tree walk
  override Void walkBottomUp(|ANode| f)
  {
    walkMetaBottomUp(f)
    walkInstancesBottomUp(f)
    f(this)
  }

  ** Tree walk
  override Void walkTopDown(|ANode| f)
  {
    f(this)
    walkMetaTopDown(f)
    walkInstancesTopDown(f)
  }

  override Void walkMetaBottomUp(|ANode| f)
  {
    meta.walkBottomUp(f)
    tops.each |x| { x.walkBottomUp(f) }
  }

  override Void walkMetaTopDown(|ANode| f)
  {
    meta.walkTopDown(f)
    tops.each |x| { x.walkTopDown(f) }
  }

  override Void walkInstancesBottomUp(|ANode| f)
  {
    instances.each |x| { if (!x.isNested) x.walkBottomUp(f) }
  }

  override Void walkInstancesTopDown(|ANode| f)
  {
    instances.each |x| { if (!x.isNested) x.walkTopDown(f) }
  }

  ** Auto naming for synthetic specs
  Str autoName() { "_" + (ast.autoNameCount++) }

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    tops.each |spec|
    {
      spec.dump(out, indent)
      out.printLine.printLine
    }

    instances.each |data|
    {
      data.dump(out, indent)
      out.printLine.printLine
    }
  }

  ** Mutable AST state
  ALibState ast() { astRef.val }
  const Unsafe astRef
}

**************************************************************************
** ALibState
**************************************************************************

@Js
internal class ALibState
{
  new make(MXetoCompiler c)
  {
    this.compiler = c
  }

  MXetoCompiler compiler
  LibFiles? files
  ADict? meta
  Int flags
  Version? version
  Str:AInstance instances := [:] { ordered = true }
  Str:ASpec tops := [:] { ordered = true }
  ASpec[]? types
  Int autoNameCount
}

