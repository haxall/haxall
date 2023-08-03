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
      case ANodeType.spec:     reifySpec(node)
      case ANodeType.dict:     reifyDict(node)
      case ANodeType.instance: reifyDict(node)
      case ANodeType.scalar:   reifyScalar(node)
      case ANodeType.dataRef:  reifyDataRef(node)
      case ANodeType.specRef:  reifySpecRef(node)
      case ANodeType.lib:      return
      default:                 throw Err(node.nodeType.name)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Specs
//////////////////////////////////////////////////////////////////////////

  private Void reifySpec(ASpec x)
  {
    // finalize the spec's metaOwn dict
    if (x.meta != null)
      x.metaOwnRef = x.meta.asm
    else
      x.metaOwnRef = env.dict0
  }

//////////////////////////////////////////////////////////////////////////
// Dict / List
//////////////////////////////////////////////////////////////////////////

  private Obj reifyDict(ADict x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // spec
    type := x.typeRef?.deref

    // turn dict into list
    if (type != null && type.isList)
      return x.asmRef = reifyList(x, type)

    // name/value pairs
    acc := Str:Obj[:]
    acc.ordered = true
    x.each |obj, name| { acc[name] = obj.asm }

    // create as Dict
    dict := env.dictMap(acc, type?.asm)
    Obj asm := dict

    // if there is a factory registered, then decode to another Fantom type
    if (type != null)
    {
      Obj? fantom
      Err? err
      try
        fantom = type.factory.decodeDict(dict, false)
      catch (Err e)
        err = e

      if (fantom != null)
      {
        asm = fantom
      }
      else
      {
        this.err("Cannot instantiate '$type.qname' dict as Fantom class '$type.factory.type'", x.loc, err)
      }
    }

    return x.asmRef = asm
  }

  private Obj[] reifyList(ADict x, CSpec spec)
  {
    // TODO: lists not being typed correctly
    of := x.listOf ?: Obj#

    list := List(of, x.size)
    x.each |obj| { list.add(obj.asm) }
    return list.toImmutable
  }

//////////////////////////////////////////////////////////////////////////
// Scalar
//////////////////////////////////////////////////////////////////////////

  private Obj? reifyScalar(AScalar x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // if there is no type, then assume string
    if (x.typeRef == null) return x.asmRef = x.str

    // map to Fantom type to parse
    type := x.ctype
    factory := type.factory
    fantom := factory.decodeScalar(x.str, false)
    if (fantom == null)
    {
      err("Invalid '$type.qname' value: $x.str.toCode", x.loc)
      fantom = x.str
    }
    // echo("___ reifyScalar $type => $factory.typeof | $fantom [$fantom.typeof]")
    return x.asmRef = fantom
  }

//////////////////////////////////////////////////////////////////////////
// DataRef
//////////////////////////////////////////////////////////////////////////

  private Obj? reifyDataRef(ADataRef x)
  {
     x.asmRef = x.isResolved ? x.deref.id : env.ref(x.toStr, null)
  }

//////////////////////////////////////////////////////////////////////////
// SpecRef
//////////////////////////////////////////////////////////////////////////

  private Obj? reifySpecRef(ASpecRef x)
  {
    x.deref
  }
}