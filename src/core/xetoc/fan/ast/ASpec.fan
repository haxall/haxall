//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Mar 2023  Brian Frank  Creation
//   3 Jul 2023  Brian Frank  Redesign the AST
//

using util
using xeto

**
** AST spec
**
@Js
internal class ASpec : ANode, CSpec
{
   ** Constructor
  new make(FileLoc loc, ALib lib, ASpec? parent, Str name) : super(loc)
  {
    this.lib    = lib
    this.parent = parent
    this.qname  = parent == null ? "${lib.name}::$name" : "${parent.qname}.$name"
    this.name   = name
    this.asm    = parent == null ? XetoType() : XetoSpec()
  }

  ** Node type
  override ANodeType nodeType() { ANodeType.spec }

  ** Parent library
  ALib lib { private set }

  ** Parent spec or null if this is top-level spec
  ASpec? parent { private set }

  ** Is this a library top level spec
  Bool isTop() { parent == null }

  ** Name within lib or parent
  const override Str name

  ** Qualified name
  const override Str qname

  ** XetoSpec for this spec - we backpatch the "m" field in Assemble step
  const override XetoSpec asm

  ** String returns qname
  override Str toStr() { qname }

  ** Resolved type ref
  CSpec? type() { typeRef?.deref }

  ** Type signature
  ASpecRef? typeRef

  ** We refine type and base in InheritSlots step
  CSpec? base

  ** Meta dict if there was "<>"
  ADict? meta { private set }

  ** Return if meta has the given tag
  Bool metaHas(Str name)
  {
    meta != null && meta.has(name)
  }

  ** Initialize meta data dict
  ADict initMeta()
  {
    if (meta == null)
    {
      meta = ADict(this.loc, null)
    }
    return this.meta
  }

  ** Slots if there was "{}"
  [Str:ASpec]? slots { private set }

  ** Initialize slots map
  Str:ASpec initSlots()
  {
    if (this.slots == null)
    {
      this.slots = Str:ASpec[:]
      this.slots.ordered = true
    }
    return this.slots
  }

  ** Default value if spec had scalar value
  AScalar? val

  ** Tree walk
  override Void walk(|ANode| f)
  {
    if (typeRef != null) typeRef.walk(f)
    if (meta != null) meta.walk(f)
    if (slots != null) slots.each |x| { x.walk(f) }
    if (val != null) val.walk(f)
    f(this)
  }

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    indentMore := indent + "  "
    out.print(indent).print(name).print(": ")
    if (typeRef != null) out.print(typeRef).print(" ")
    if (meta != null) meta.dump(out, indentMore)
    if (slots != null)
    {
      out.printLine("{")
      slots.each |s|
      {
        s.dump(out, indentMore)
        out.printLine
      }
      out.print(indent).print("}")
    }
    if (val != null) out.print(" = ").print(val)
  }

  ** The answer is yes
  override Bool isAst() { true }

  ** Resolved type
  override CSpec? ctype() { type }

  ** Resolved base
  override CSpec? cbase() { throw Err("TODO") }

  ** Lookup effective slot
  override CSpec? cslot(Str name, Bool checked := true)
  {
    ast := slots?.get(name) as ASpec
    if (ast != null) return ast
    if (checked) throw UnknownSlotErr(name)
    return null
  }

  ** Factory for spec type
  override SpecFactory factory() { factoryRef ?: throw NotReadyErr(qname) }

  ** Factory resolved in LoadFactories
  SpecFactory? factoryRef

  ** Declared meta (set in Reify)
  Dict metaOwn() { metaOwnRef ?: throw NotReadyErr(qname) }
  Dict? metaOwnRef

  ** Effective meta (set in InheritMeta)
  override Dict cmeta() { cmetaRef ?: throw NotReadyErr(qname) }
  Dict? cmetaRef

  ** Iterate the effective slots
  override Str:CSpec cslots() { cslotsRef ?: throw NotReadyErr(qname) }
  [Str:CSpec]? cslotsRef

  ** Extract 'ofs' list of type refs from AST model
  override once CSpec[]? cofs()
  {
    if (meta == null) return null
    list := meta.get("ofs") as ADict
    if (list == null) return null
    acc := CSpec[,]
    list.map.each |x| { acc.add(((ASpecRef)x).deref) }
    return acc.ro
  }

  ** Inheritance flags computed in InheritSlots
  override Int flags

  Bool isScalar() { hasFlag(MSpecFlags.scalar) }
  override Bool isMaybe() { hasFlag(MSpecFlags.maybe) }
  override Bool isQuery() { hasFlag(MSpecFlags.query) }

  Bool hasFlag(Int flag) { flags.and(flag) != 0 }

}


