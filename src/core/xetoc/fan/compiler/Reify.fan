//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using xetom
using haystack

**
** Reify creates concrete Fantom object for all the AData objects
** in the abstract syntax tree as their assembly value.  We use this
** step to finalize the ASpec.metaOwn dict.
**
** We run this in two passes: first to reify lib/spec meta; then for instances.
**
@Js
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
    if (x.ast.meta != null)
      x.ast.metaOwn = x.ast.meta.asm
    else
      x.ast.metaOwn = Etc.dict0
  }

//////////////////////////////////////////////////////////////////////////
// Dict / List
//////////////////////////////////////////////////////////////////////////

  private Obj reifyDict(ADict x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // turn ADict into raw Dict or Obj?[]
    type := x.type
    isList := type.isList
    Obj? asm
    if (isList)
    {
      asm = reifyRawList(x, type)
    }
    else if (type.isGrid)
    {
      asm = reifyGrid(x, type)
    }
    else
    {
      asm = reifyRawDict(x, type)

      // use binding to potentially decode to another Fantom type
      binding := type.binding
      Obj? fantom
      Err? err
      try
        fantom = binding.decodeDict(asm)
      catch (Err e)
        err = e

      if (fantom != null)
      {
        asm = fantom
      }
      else
      {
        this.err("Cannot instantiate '$type.qname' dict as Fantom class '$binding.type'", x.loc, err)
      }
    }

    x.asmRef = asm
    return asm
  }

  private Dict reifyRawDict(ADict x, Spec type)
  {
    // name/value pairs
    acc := Str:Obj[:]
    acc.ordered = true
    x.each |obj, name| { acc[name] = reifyDictVal(obj) }

    // if spec is not meta or sys::Dict then add synthetic spec tag
    if (!x.isMeta && type.qname != "sys::Dict")
      acc["spec"] = compiler.makeRef(type.qname, null)

    // create as Dict
    return Etc.dictFromMap(acc)
  }

  private Obj[] reifyRawList(ADict x, Spec type)
  {
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
// Grid
//////////////////////////////////////////////////////////////////////////

  ** Convert a grid shaped dict to a true Grid - see doc.xeto::Grids.
  ** The same shape decodes off the wire in JetoReader.convertGrid; here
  ** the decode is compile time so errors carry source locations.
  private Obj reifyGrid(ADict x, Spec type)
  {
    // a grid is a value, never a named instance with an id - same rule as List
    if (x.nodeType.isInstance) err("Grid cannot be a named instance", x.loc)

    cols := x.get("cols") as ADict
    rows := x.get("rows") as ADict
    if (cols == null || rows == null)
    {
      missing := cols == null ? "cols" : "rows"
      err("Grid missing '$missing' list", x.loc)
      return reifyRawDict(x, type)
    }

    gb := GridBuilder()

    // grid meta: the structural 'spec' and 'of' refs sit beside the
    // domain meta tags; the sys::Grid default is elided
    ofSpec := (x.get("of") as ASpecRef)?.deref
    gt := type.type
    meta := shapeMeta(gt.qname != "sys::Grid" ? gt.id : null, ofSpec, x.get("meta"))
    if (meta != null) gb.setMeta(meta)

    // cols; 'of' is structural and sits beside 'name', not inside meta
    cols.each |c|
    {
      cd := c as ADict
      name := cd?.getStr("name")
      if (name == null) { err("Grid col missing 'name'", c.loc); return }
      gb.addCol(name, shapeMeta(null, (cd.get("of") as ASpecRef)?.deref, cd.get("meta")))
    }

    // rows are ordinary dicts whose cells were typed at infer time
    rows.each |r|
    {
      rd := r as ADict
      if (rd == null) { err("Grid row is not a dict", r.loc); return }
      gb.addDictRow((Dict)rd.asm)
    }

    return gb.toGrid
  }

  ** Build grid or col meta: structural refs first, then the domain tags
  ** from the shape's own meta dict.  Returns null when empty.
  private Dict? shapeMeta(Ref? specRef, Spec? of, AData? wireData)
  {
    wire := wireData?.asm as Dict
    if (specRef == null && of == null && (wire == null || wire.isEmpty)) return null
    acc := Str:Obj[:] { ordered = true }
    if (specRef != null) acc["spec"] = specRef
    if (of != null) acc["of"] = of.id
    wire?.each |v, n| { acc[n] = v }
    return Etc.dictFromMap(acc)
  }


//////////////////////////////////////////////////////////////////////////
// Scalar
//////////////////////////////////////////////////////////////////////////

  private Obj? reifyScalar(AScalar x)
  {
    // if already assembled
    if (x.isAsm) return x.asm

    // map to Fantom type to parse
    type := x.type
    try
    {
      binding := type.binding
      fantom := binding.decodeScalar(x.str, false)
      if (fantom == null)
      {
        err("Invalid '$type.qname' string value: $x.str.toCode", x.loc)
        fantom = x.str
      }

      // echo("___ reifyScalar $type => $factory.typeof | $fantom [$fantom.typeof]")
      x.asmRef = fantom
    }
    catch (Err e)
    {
      err("Cannot decode scalar '$type': $e", x.loc)
      x.asmRef = "error"
    }
    return x.asmRef
  }

//////////////////////////////////////////////////////////////////////////
// DataRef
//////////////////////////////////////////////////////////////////////////

  private Obj? reifyDataRef(ADataRef x)
  {
     x.asmRef = x.isResolved ? x.deref.id : compiler.makeRef(x.toStr, x.dis)
     return x.asmRef
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

@Js
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

@Js
internal class ReifyInstances : Reify
{
  override Void run()
  {
    ast.walkInstancesBottomUp |node| { reify(node) }
  }
}

