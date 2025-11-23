//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Nov 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Document is top-level AST node - either a ALib or ADataDoc
**
@Js
internal mixin ADoc : ANode
{
  ** Compiler
  abstract MXetoCompiler compiler()

  ** Instance data
  abstract Str:AInstance instances()

  ** Lookup top level instance data
  AData? instance(Str name) { instances.get(name) }

  ** Walk lib and spec meta top-down (we also walk ASpecs themselves)
  abstract Void walkMetaTopDown(|ANode| f)

  ** Walk lib and spec meta bottom-down (we also walk ASpecs themselves)
  abstract Void walkMetaBottomUp(|ANode| f)

  ** Walk only instances top-down
  abstract Void walkInstancesTopDown(|ANode| f)

  ** Walk only instances bottom-up
  abstract Void walkInstancesBottomUp(|ANode| f)

}

**************************************************************************
** ADataDoc
**************************************************************************

**
** Top-level node for a data file, it just wraps a root AData node
**
@Js
internal class ADataDoc : ADoc
{
   ** Constructor
  new make(MXetoCompiler c, FileLoc loc)
  {
    this.loc = loc
    this.compiler = c
  }

  ** File location
  override const FileLoc loc

  ** Compiler
  override MXetoCompiler compiler

  ** Root data object wrapped - set by Parser.parseDataFile
  AData? root

  ** Instance data
  override Str:AInstance instances := [:] { ordered = true }

  override ANodeType nodeType() { ANodeType.dataDoc }

  override Obj asm() { root.asm }

  override Void walkBottomUp(|ANode| f) { root.walkBottomUp(f) } // don't walk myself

  override Void walkTopDown(|ANode| f) { root.walkTopDown(f) } // don't walk myself

  override Void walkMetaTopDown(|ANode| f) {}

  override Void walkMetaBottomUp(|ANode| f) {}

  override Void walkInstancesTopDown(|ANode| f) { walkTopDown(f) }

  override Void walkInstancesBottomUp(|ANode| f) { walkBottomUp(f) }

  override Void dump(OutStream out := Env.cur.out, Str indent := "") { root.dump(out, indent) }

}

