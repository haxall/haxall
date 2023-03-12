//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Mar 2023  Brian Frank  Creation
//

using util

**
** AST base class for object productions:
**    - AVal: compiles into scalar/list/dict for values
**    - ASpec: compiles into slot/nested XetoSpec
**    - AType: compiles into named XetoType
**    - ALib:  compiles into named XetoLib
**
@Js
internal abstract class AObj : ANode
{
  ** Constructor
  new make(FileLoc loc, AObj? parent, Str name)
  {
    this.loc    = loc
    this.parent = parent
    this.name   = name
  }

  ** Source code location
  const override FileLoc loc

  ** Simple name
  const Str name

  ** Parent spec (null for lib, root data)
  AObj? parent { private set }

  ** Is this an spec subtype including type/lib
  virtual Bool isSpec() { false }

  ** Type ref for this object.  Null if this is Obj or we need to infer type
  ARef? type

  ** Meta tags if there was '<>'
  AVal? meta { private set }

  ** Children slots if there was '{}'
  AMap? slots { private set }

  ** Scalar value
  AScalar? val

  ** Return value type qname for parsing
  virtual Str valParseType() { type.qname }

  ** Initialize meta data dict
  AVal initMeta(ASys sys)
  {
    if (meta == null)
    {
      meta = AVal(loc, this, "meta")
      meta.type = sys.dict
      meta.initSlots
    }
    return meta
  }

  ** Create new AVal with this's type+meta, then clear this's type+meta.
  AObj wrapSpec(Str name)
  {
    of := this.meta == null ? AVal(loc, this, name) : ASpec(loc, this, name)
    of.type = this.type
    of.meta = this.meta
    this.type = null
    this.meta = null
    return of
  }

  ** Initialize slots map
  AMap initSlots()
  {
    if (slots == null) slots = AMap()
    return slots
  }

  ** Lookup a slot by name
  AObj? slot(Str name) { slots?.get(name) }

  ** Construct proper child object for parser to use
  abstract AObj makeChild(FileLoc loc, Str name)

  ** Walk AST tree
  override Void walk(|ANode| f)
  {
    type?.walk(f)
    meta?.walk(f)
    slots?.walk(f)
    f(this)
  }

  ** Debug string
  override final Str toStr()
  {
    s := StrBuf()
    s.add(name).add(":")
    if (type != null) s.join(type, " ")
    if (val != null) s.join(val, " ")
    //s.add("[").add(nodeType).add(", ").add(loc).add("]")
    return s.toStr
  }

  ** Dump
  /*
  Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    out.print(indent).printLine(this)
    if (meta != null)
    {
      out.print(indent).printLine("<")
      meta.slots.each |kid| { kid.dump(out, indent+"  ") }
      out.print(indent).printLine(">")
    }
    if (slots != null)
    {
      out.print(indent).printLine("{")
      slots.each |kid| { kid.dump(out, indent+"  ") }
      out.print(indent).printLine("}")
    }
    if (nodeType === ANodeType.type) out.printLine
  }
  */

}