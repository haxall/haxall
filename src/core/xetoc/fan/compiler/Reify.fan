//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Reify creates concrete Fantom object for all the AData objects
** in the abstract syntax tree as their assembly value.  We use this
** step to finalize the ASpec.metaOwn dict.
**
** We run this in two passes: first to reify lib/spec meta; then for instances.
**
internal abstract class Reify : Step
{
  Void reify(ANode node)
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
      x.metaOwnRef = MNameDict.empty
  }

//////////////////////////////////////////////////////////////////////////
// Dict / List
//////////////////////////////////////////////////////////////////////////

  private Obj reifyDict(ADict x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // turn ADict into raw Dict or Obj?[]
    type := x.ctype
    isList := type.isList
    Obj? asm
    if (isList)
      asm = reifyRawList(x, type)
    else
      asm = reifyRawDict(x, type)

    // if there is a factory registered, then decode to another Fantom type
    factory := type.factory
    Obj? fantom
    Err? err
    try
      fantom = isList ? factory.decodeList(asm, false) : factory.decodeDict(asm, false)
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

    return x.asmRef = asm
  }

  private Dict reifyRawDict(ADict x, CSpec type)
  {
    // name/value pairs
    acc := Str:Obj[:]
    acc.ordered = true
    x.each |obj, name| { acc[name] = reifyDictVal(obj) }

    // if spec is not meta or sys::Dict then add synthetic spec tag
    if (!x.isMeta && type.qname != "sys::Dict")
      acc["spec"] = compiler.makeRef(type.qname, null)

    // create as Dict
    return MNameDict(names.dictMap(acc))
  }

  private Obj[] reifyRawList(ADict x, CSpec type)
  {
    // TODO: lists not being typed correctly
    of := x.listOf ?: Obj#

    list := List(of, x.size)
    x.each |obj| { list.add(reifyDictVal(obj)) }
    return list.toImmutable
  }

  private Obj reifyDictVal(ANode x)
  {
    if (x.nodeType === ANodeType.specRef)
      return ((ASpecRef)x).deref.id
    else
      return x.asm
  }

//////////////////////////////////////////////////////////////////////////
// Scalar
//////////////////////////////////////////////////////////////////////////

  private Obj? reifyScalar(AScalar x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // map to Fantom type to parse
    try
    {
      type := x.ctype
      factory := type.factory
      fantom := factory.isGenericScalar ?
                Scalar(x.ctype.qname, x.str) :
                factory.decodeScalar(x.str, false)
      if (fantom == null)
      {
        err("Invalid '$type.qname' string value: $x.str.toCode", x.loc)
        fantom = x.str
      }

      // echo("___ reifyScalar $type => $factory.typeof | $fantom [$fantom.typeof]")
      return x.asmRef = fantom
    }
    catch (Err e)
    {
      err("Cannot decode scalar: $e", x.loc)
      return x.asmRef = "error"
    }
  }

//////////////////////////////////////////////////////////////////////////
// DataRef
//////////////////////////////////////////////////////////////////////////

  private Obj? reifyDataRef(ADataRef x)
  {
     x.asmRef = x.isResolved ? x.deref.id : compiler.makeRef(x.toStr, x.dis)
  }

//////////////////////////////////////////////////////////////////////////
// SpecRef
//////////////////////////////////////////////////////////////////////////

  private Obj? reifySpecRef(ASpecRef x)
  {
    x.deref.id
  }
}

**************************************************************************
** ReifyMeta
**************************************************************************

internal class ReifyMeta : Reify
{
  override Void run()
  {
    ast.walkMetaBottomUp |node| { reify(node)  }
  }
}

**************************************************************************
** ReifyInstances
**************************************************************************

internal class ReifyInstances : Reify
{
  override Void run()
  {
    ast.walkInstancesBottomUp |node| { reify(node) }
  }
}

