//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jul 2023  Brian Frank  Creation
//

using util
using xeto

**
** Walk thru all the dict AST instances and add inferred tags
**
**
@Js
internal class InferData : Step
{
  override Void run()
  {
    ast.walk |node|
    {
      if (node.nodeType === ANodeType.dict) infer(node)
    }
  }

  private Void infer(ADict dict)
  {
    inferId(dict)
  }

  private Void inferId(ADict dict)
  {
    if (dict.id == null) return

    // make id qualified if this is lib data
    id := dict.id.toStr
    if (isLib) id = lib.name + "::" + id

    // add "id" tag with Ref scalar value
    loc := dict.loc
    ref := env.ref(id, null)
    if (dict.has("id")) err("Named dict cannot have explicit id tag", loc)
    dict.set("id", AScalar(loc, sys.ref, id, ref))
  }

}