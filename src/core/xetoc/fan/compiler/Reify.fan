//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2023  Brian Frank  Creation
//

using util
using xeto

**
** Reify creates concrete Fantom object for all the AData objects
** in the abstract syntax tree as their assembly value.  We use this
** step to finalize the ASpec.metaOwn dict.
**
@Js
internal class Reify : Step
{
  override Void run()
  {
    ast.walk |x| { reify(x) }
  }

  private Void reify(ANode node)
  {
    switch (node.nodeType)
    {
      case ANodeType.spec:    reifySpec(node)
      case ANodeType.dict:    reifyDict(node)
      case ANodeType.scalar:  reifyScalar(node)
      case ANodeType.specRef: reifySpecRef(node)
      case ANodeType.lib:     return
      default:                throw Err(node.nodeType.name)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  private Void reifySpec(ASpec x)
  {
    // assemble default value into meta
    /*
    if (x.val != null)
    {
      // assemble as scalar using my own type
      scalarType := x.isType ? x : x.type
      val := asmScalar(x, scalarType)

      // insert into meta
      AVal obj := x.metaInit(sys).makeChild(x.val.loc, "val")
      obj.asmRef = val
      x.meta.slots.add(obj)
    }
    */

    // finalize the spec's metaOwn dict
    if (x.meta != null)
      x.metaOwnRef = x.meta.asm
    else
      x.metaOwnRef = env.dict0
  }

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  private Dict reifyDict(ADict x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // spec
    spec := x.typeRef?.asm

    // name/value pairs
    acc := Str:Obj[:]
    acc.ordered = true
    x.map.each |obj, name| { acc[name] = obj.asm }

    return x.asmRef = env.dictMap(acc, spec)
  }

//////////////////////////////////////////////////////////////////////////
// Scalar
//////////////////////////////////////////////////////////////////////////

  private Obj? reifyScalar(AScalar x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // sanity check
    if (x.typeRef == null)
    {
      //throw err("reifyScalar without type", x.loc)
echo("TODO: reifyScalar without type [$x.loc]")
return x.asmRef = x.str
    }

    // map to Fantom type to parse
    type := x.type
    factory := type.factory
    fantom := factory.decodeScalar(x.str, false)
    if (fantom == null)
    {
      err("Invalid '$type.qname' value: $x.str.toCode", x.loc)
      fantom = x.str
    }
    // echo("___ reifyScalar $type => $fantom [$fantom.typeof]")
    return x.asmRef = fantom
  }

//////////////////////////////////////////////////////////////////////////
// SpecRef
//////////////////////////////////////////////////////////////////////////

  private Obj? reifySpecRef(ASpecRef x)
  {
    x.deref
  }
}