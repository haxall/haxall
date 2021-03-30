//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Dec 2018  Brian Frank  Creation
//

using haystack

**
** DocDefTree
**
class DocDefTree
{
  new make(DocDefTree? parent, DocDef def)
  {
    this.parent = parent
    this.def = def
  }

  DocDefTree? parent

  DocDef def

  Bool isEmpty() { kids.isEmpty }

  override Int compare(Obj that) { this.def <=> ((DocDefTree)that).def }

  DocDefTree add(DocDef def)
  {
    kid := DocDefTree(this, def)
    kids.add(kid)
    return kid
  }

  Void each(|Int, DocDef| f)
  {
    doEach(-1, f)
  }

  Void doEach(Int indent, |Int,DocDef| f)
  {
    if (indent >= 0) f(indent, def)
    kids.dup.sort.each |kid| { kid.doEach(indent+1, f) }
  }

  DocDefTree invert()
  {
    // find leafs which become our new roots
    leafs := DocDefTree[,]
    findLeafs(leafs)

    // walk leafs and invert their parent paths into children paths
    root := DocDefTree(null, def)
    nodes := Str:DocDefTree[:]
    leafs.each |leaf|
    {
      addPath(nodes, root, leaf)
    }

    return root
  }

  private Void findLeafs(DocDefTree[] acc)
  {
    if (kids.isEmpty) acc.add(this)
    else kids.each |kid| { kid.findLeafs(acc) }
  }

  private Void addPath(Str:DocDefTree nodes, DocDefTree parent, DocDefTree x)
  {
    // don't map root of original tree
    if (x.parent == null) return

    // add into tree if not there already
    node := nodes[x.def.name]
    if (node == null)
    {
      node = parent.add(x.def)
      nodes[x.def.name] = node
    }

    // recurse
    if (x.parent != null) addPath(nodes, node, x.parent)
  }

  private DocDefTree[] kids := [,]
}