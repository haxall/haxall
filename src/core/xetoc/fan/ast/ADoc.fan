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
internal abstract class ADoc : ANode
{
   ** Constructor
  new make(XetoCompiler c, FileLoc loc) : super(loc)
  {
    this.compiler = c
  }

  ** Compiler
  XetoCompiler compiler { private set }

  ** Instance data
  Str:AInstance instances := [:] { ordered = true }

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
internal class ADataDoc : ADoc
{
   ** Constructor
  new make(XetoCompiler c, FileLoc loc) : super(c, loc) {}

  ** Root data object wrapped - set by Parser.parseDataFile
  AData? root

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

