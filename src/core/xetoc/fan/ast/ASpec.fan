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
using xetom
using haystack

**
** AST spec
**
@Js
internal class ASpec : ANode, CSpec
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

   ** Constructor
  new make(FileLoc loc, ALib lib, ASpec? parent, Str name)
  {
    this.loc      = loc
    this.lib      = lib
    this.parent   = parent
    this.qname    = parent == null ? "${lib.name}::$name" : "${parent.qname}.$name"
    this.flavor   = toFlavor(parent, name)
    this.name     = name
  }

  private static SpecFlavor toFlavor(ASpec? parent, Str name)
  {
    if (parent != null)  return SpecFlavor.slot
    if (name[0].isLower) return SpecFlavor.global
    return SpecFlavor.type
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** File location
  override const FileLoc loc

  ** Node type
  override ANodeType nodeType() { ANodeType.spec }

  ** Parent library
  ALib lib { private set }

  ** Reference to compiler
  MXetoCompiler compiler() { lib.compiler }

  ** Reference to system types
  ASys sys() { lib.compiler.sys }

  ** Parent spec or null if this is top-level spec
  ASpec? parent { private set }

  ** Flavor for spec
  override SpecFlavor flavor

  ** Is this a library top level spec
  Bool isTop() { flavor.isTop }

  ** Is flavor type
  Bool isType() { flavor.isType }

  ** Is flavor mixin
  Bool isMixin() { flavor.isMixin }

  ** Is flavor global
  override Bool isGlobal()
  {
// TODO
    if (flags < 0) return cmetaHas("global")
    return flavor.isGlobal || hasFlag(MSpecFlags.global)
  }

  ** Is flavor meta
  Bool isMeta() { flavor.isMeta }

  ** Are we compiling sys itself
  override Bool isSys() { lib.isSys }

  ** Is this a slot spec
  Bool isSlot() { parent != null }

  ** Name within lib or parent
  const override Str name

  ** Qualified name
  const override Str qname

  ** Ref of qualified name
  override once Ref id() { Ref(qname, null) }

  ** XetoSpec for this spec - we backpatch the "m" field in Assemble step
  const override XetoSpec asm := XetoSpec()

  ** String returns qname
  override Str toStr() { qname }

  ** Is given spec the 'sys::Obj' type
  Bool isObj() { lib.isSys && name == "Obj" }

  ** Type signature after colon - set in Parser, InheritSlots.
  ** This is base for top-level types and value type for slots.
  ** Note ctype is different because it is this for top-level types.
  ASpecRef? typeRef

  ** We refine type and base in InheritSlots step
  CSpec? base

  ** Default value if spec had scalar value
  AScalar? val

  ** Parameterized arguments of/ofs (set in InheritMeta)
  override MSpecArgs args() { argsRef ?: throw NotReadyErr(qname) }
  internal MSpecArgs? argsRef

  ** True if we parsed this spec as an '&' or '|' type
  Bool parsedCompound

  ** True if we parsed this as a nested spec ref
  Bool parsedSyntheticRef

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  ** Declared meta if there was "<>"
  ADict? meta { private set }

  ** Initialize meta data dict
  ADict metaInit()
  {
    if (meta == null) meta = ADict(this.loc, compiler.sys.spec, true)
    meta.metaParent = this
    return this.meta
  }

  ** Return if meta has the given tag
  Bool metaHas(Str name)
  {
    meta != null && meta.has(name)
  }

  ** Get meta
  AData? metaGet(Str name)
  {
    meta?.get(name)
  }

  ** Set meta-data tag
  Void metaSet(Str name, AData data)
  {
    metaInit.set(name, data)
  }

  ** Set the given meta tag to marker singleton
  Void metaSetMarker(Str name)
  {
    metaSet(name, sys.markerScalar(loc))
  }

  ** Set the given meta tag to none singleton
  Void metaSetNone(Str name)
  {
    metaSet(name, AScalar(loc, sys.none, "none", Remove.val))
  }

  ** Set the given meta tag to string value
  Void metaSetStr(Str name, Str val)
  {
    metaSet(name, AScalar(loc, sys.str, val, val))
  }

  ** Set the "ofs" meta tag
  Void metaSetOfs(Str name, ASpecRef[] specs)
  {
    c := compiler
    first := specs[0]
    loc := first.loc
    list := ADict(loc, sys.list)
    list.listOf = Ref#
    specs.each |spec, i|
    {
      list.set(c.autoName(i), spec)
    }
    metaSet("ofs", list)
  }

//////////////////////////////////////////////////////////////////////////
// Slots
//////////////////////////////////////////////////////////////////////////

  ** Members (slots & globals) if there was "{}"
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

//////////////////////////////////////////////////////////////////////////
// AST Node
//////////////////////////////////////////////////////////////////////////

  ** Tree walk
  override Void walkBottomUp(|ANode| f)
  {
    if (typeRef != null) typeRef.walkBottomUp(f)
    if (meta != null) meta.walkBottomUp(f)
    if (slots != null) slots.each |x| { x.walkBottomUp(f) }
    if (val != null) val.walkBottomUp(f)
    f(this)
  }

  ** Tree walk
  override Void walkTopDown(|ANode| f)
  {
    if (typeRef != null) typeRef.walkTopDown(f)
    f(this)
    if (meta != null) meta.walkTopDown(f)
    if (slots != null) slots.each |x| { x.walkTopDown(f) }
    if (val != null) val.walkTopDown(f)
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

//////////////////////////////////////////////////////////////////////////
// CSpec
//////////////////////////////////////////////////////////////////////////

  ** The answer is yes
  override Bool isAst() { true }

  ** Resolved type
  override CSpec ctype() { isType ? this : typeRef.deref }

  ** Resolved base
  override CSpec? cbase() { base }

  ** Parent spec or null if this is top-level spec
  override CSpec? cparent() { parent }

  ** Binding (set in LoadBindings)
  override SpecBinding binding() { bindingRef ?: throw NotReadyErr(qname) }
  SpecBinding? bindingRef

  ** Declared meta (set in Reify)
  Dict metaOwn() { metaOwnRef ?: throw NotReadyErr(qname) }
  Dict? metaOwnRef

  ** Effective meta (set in InheritMeta)
  override Dict cmeta() { cmetaRef ?: throw NotReadyErr(qname) }
  Dict? cmetaRef

  ** Effective meta has
  override Bool cmetaHas(Str name)
  {
    if (cmetaRef != null) return cmetaRef.has(name)
    return metaHas(name)
  }

  ** Is there one or more effective slots
  override Bool hasSlots()
  {
    if (cslotsRef == null) throw NotReadyErr(qname)
    return !cslotsRef.isEmpty
  }

  ** Iterate the effective members
  override Void cmembers(|CSpec, Str| f)
  {
    if (cslotsRef == null) throw NotReadyErr(qname)
    cslotsRef.each(f)
  }

  ** Lookup effective member
  override CSpec? cmember(Str name, Bool checked := true)
  {
    if (cslotsRef == null) throw NotReadyErr(qname)
    m := cslotsRef.get(name)
    if (m != null) return m
    if (checked) throw UnknownSlotErr("${qname}.${name}")
    return null
  }

  ** Iterate the effective slots
  ** TODO: make this slots only?
  override Void cslots(|CSpec, Str| f)
  {
    if (cslotsRef == null) throw NotReadyErr(qname)
    cslotsRef.each(f)
  }

  ** Iterate the effective slots
  override Obj? cslotsWhile(|CSpec, Str->Obj?| f)
  {
    if (cslotsRef == null) throw NotReadyErr(qname)
    return cslotsRef.eachWhile(f)
  }

  ** Effective slots configured in InheritSlots
  [Str:CSpec]? cslotsRef

  ** Enum items
  override CSpec? cenum(Str key, Bool checked := true)
  {
    if (!isEnum) throw Err(qname)
    if (enums == null) throw NotReadyErr(qname)
    x := enums[key]
    if (x != null) return x
    if (checked) throw Err(key)
    return null
  }

  // Map of enum items by string kehy (set in InheritSlots)
  [Str:CSpec]? enums

  ** Return if spec inherits from that from a nominal type perspective.
  ** This is the same behavior as Spec.isa, just using CSpec (XetoSpec or AST)
  override Bool cisa(CSpec that)
  {
    if (XetoUtil.isa(this, that)) return true
    if (this.qname == that.qname) return true
    return false
  }

  ** Extract 'of' type ref from AST model
  override once CSpec? cof()
  {
    if (meta == null) return null
    x := meta.get("of") as ASpecRef
    if (x == null) return null
    return x.deref
  }

  ** Extract 'ofs' list of type refs from AST model
  override once CSpec[]? cofs()
  {
    if (meta == null) return null
    list := meta.get("ofs") as ADict
    if (list == null) return null
    acc := CSpec[,]
    list.each |x| { acc.add(((ASpecRef)x).deref) }
    return acc.ro
  }

  override Bool isNone() { isSys && name == "None" }

  override Bool isSelf() { isSys && name == "Self" }

  override Bool isEnum() { base != null && base.isSys && base.name == "Enum" }

  override Bool isAnd() { base != null && base.isSys && base.name == "And" }

  override Bool isOr() { base != null && base.isSys && base.name == "Or" }

  ** Inheritance flags computed in InheritSlots
  override Int flags := -1

  override Bool isScalar()    { hasFlag(MSpecFlags.scalar) }
  override Bool isMarker()    { hasFlag(MSpecFlags.marker) }
  override Bool isRef()       { hasFlag(MSpecFlags.ref) }
  override Bool isMultiRef()  { hasFlag(MSpecFlags.multiRef) }
  override Bool isChoice()    { hasFlag(MSpecFlags.choice) }
  override Bool isDict()      { hasFlag(MSpecFlags.dict) }
  override Bool isList()      { hasFlag(MSpecFlags.list) }
  override Bool isMaybe()     { hasFlag(MSpecFlags.maybe) }
  override Bool isQuery()     { hasFlag(MSpecFlags.query) }
  override Bool isFunc()      { hasFlag(MSpecFlags.func) }
  override Bool isInterface() { hasFlag(MSpecFlags.interface) }
  override Bool isComp()      { hasFlag(MSpecFlags.comp) }

  /*
  override Bool isNone()   { hasFlag(MSpecFlags.none) }
  override Bool isSelf()   { hasFlag(MSpecFlags.self) }
  override Bool isEnum()   { hasFlag(MSpecFlags.enum) }
  override Bool isAnd()    { hasFlag(MSpecFlags.and) }
  override Bool isOr()     { hasFlag(MSpecFlags.or) }
  */

  Bool hasFlag(Int flag)
  {
    if (flags < 0) throw Err("Flags not set yet: $qname")
    return flags.and(flag) != 0
  }

  Bool isInterfaceSlot()
  {
    parent != null && parent.isInterface
  }
}

