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
internal abstract class AObj
{
  ** Constructor
  new make(FileLoc loc, AObj? parent, Str name)
  {
    this.loc       = loc
    this.parentRef = parent
    this.nameRef   = name
  }

  ** Source code location
  const FileLoc loc

  ** Simple name
  Str name() { nameRef }
  const Str nameRef

  ** Parent spec (null for lib, root data)
  virtual AObj? parent() { parentRef }
  private AObj? parentRef

  ** Is this an ASpec instance or subclass
  virtual Bool isSpec() { false  }

  ** Is this an AType instance
  virtual Bool isType() { false }

  ** Is this an ALib instance
  virtual Bool isLib() { false }

  ** Is this an AVal instance
  virtual Bool isVal() { false }

  ** Assembled value - raise NotAssembledErr if not assembled
  abstract Obj asm()

  ** Type ref for this object.  Null if this is Obj or we need to infer type
  ARef? typeRef

  ** Resolved type ref
  CSpec? type() { typeRef?.resolved }

  ** Meta tags if there was '<>'
  AVal? meta { private set }

  ** Children slots if there was '{}'
  AMap? slots { private set }

  ** Scalar value
  AScalar? val

  ** Return value type qname for parsing
  virtual Str valParseType() { type.qname }

  ** Initialize meta data dict
  AVal metaInit(ASys sys)
  {
    if (meta == null)
    {
      meta = AVal(loc, this, "meta")
      meta.typeRef = sys.dict
      meta.initSlots
    }
    return meta
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