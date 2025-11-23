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
internal final const class ASpec : ANode, CSpec, Spec
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

   ** Constructor
  new make(FileLoc loc, ALib lib, ASpec? parent, Str name)
  {
    this.loc    = loc
    this.astRef = Unsafe(ASpecState(lib, parent, toFlavor(parent, name)))
    this.qname  = parent == null ? "${lib.name}::$name" : "${parent.qname}.$name"
    this.name   = name
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
  override ALib lib() { ast.lib }

  ** Reference to compiler
  MXetoCompiler compiler() { lib.compiler }

  ** Reference to system types
  ASys sys() { lib.compiler.sys }

  ** Parent spec or null if this is top-level spec
  override ASpec? parent() { ast.parent }

  ** Flavor for spec
  override SpecFlavor flavor() { ast.flavor }

  ** Is this a library top level spec
  Bool isTop() { flavor.isTop }

  ** Is flavor type
  override Bool isType() { flavor.isType }

  ** Is flavor mixin
  override Bool isMixin() { flavor.isMixin }

  ** Is flavor global
  override Bool isGlobal()
  {
// TODO
    if (flags < 0) return metaHas("global")
    return flavor.isGlobal || hasFlag(MSpecFlags.global)
  }

  ** Is flavor meta
  override Bool isMeta() { flavor.isMeta }

  ** Are we compiling sys itself
  override Bool isSys() { lib.isSys }

  ** Is this a slot spec
// TODO: make this isMember
  override Bool isSlot() { parent != null }

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
  ASpecRef? typeRef { get { ast.typeRef } set { ast.typeRef = it } }

  ** We refine type and base in InheritSlots step
  override Spec? base() { ast.base as Spec }

  ** Default value if spec had scalar value
  AScalar? val() { ast.val }

  ** Parameterized arguments of/ofs (set in InheritMeta)
  override MSpecArgs args() { ast.args ?: throw NotReadyErr(qname) }

  ** True if we parsed this spec as an '&' or '|' type
  Bool parsedCompound() { ast.parsedCompound }

  ** True if we parsed this as a nested spec ref
  Bool parsedSyntheticRef() { ast.parsedSyntheticRef }

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  ** Declared meta if there was "<>"
  //ADict? meta() { ast.meta }

  ** Initialize meta data dict
  ADict metaInit()
  {
    ast := this.ast
    if (ast.meta == null) ast.meta = ADict(this.loc, compiler.sys.spec, true)
    ast.meta.metaParent = this
    return ast.meta
  }

  ** Return if meta has the given tag
  Bool metaHas(Str name)
  {
    ast.meta != null && ast.meta.has(name)
  }

  ** Get meta
  AData? metaGet(Str name)
  {
    ast.meta?.get(name)
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
// Members
//////////////////////////////////////////////////////////////////////////

  ** Declared members if there was "{}"
  [Str:ASpec]? declared() { ast.declared }

  ** Initialize declared members map
  Str:ASpec initDeclared()
  {
    ast := this.ast
    if (ast.declared == null)
    {
      ast.declared = Str:ASpec[:] { it.ordered = true }
    }
    return ast.declared
  }

//////////////////////////////////////////////////////////////////////////
// Spec
//////////////////////////////////////////////////////////////////////////

  override Spec type() { (Spec)ctype }

  override Dict meta() { cmeta }

  override Spec? member(Str n, Bool c := true) { members.get(n, c) }

  override Spec? slot(Str n, Bool c := true) { slots.get(n, c) }

  override Spec? slotOwn(Str n, Bool c := true) { slotsOwn.get(n, c) }

  override once SpecMap members()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    ast.cslots.each |x, n| { acc.add(n, x) }
    return SpecMap(acc)
  }

  override SpecMap slots()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    ast.cslots.each |x, n| { if (!x.isGlobal) acc.add(n, x) }
    return SpecMap(acc)
  }

  override final Spec? of(Bool checked := true)
  {
    x := cof
    if (x != null) return (Spec)x
    if (checked) throw Err(qname)
    return null
  }

  override final Spec[]? ofs(Bool checked := true)
  {
    x := cofs
    if (x != null) return Spec[,].addAll((Obj)x)
    if (checked) throw Err("TODO")
    return null
  }

  override final Bool isa(Spec that)
  {
    if (XetoUtil.isa(this, (CSpec)that)) return true
    if (this.qname == that.qname) return true
    return false
  }

//////////////////////////////////////////////////////////////////////////
// AST Node
//////////////////////////////////////////////////////////////////////////

  ** Tree walk
  override Void walkBottomUp(|ANode| f)
  {
    if (typeRef != null) typeRef.walkBottomUp(f)
    if (ast.meta != null) ast.meta.walkBottomUp(f)
    if (declared != null) declared.each |x| { x.walkBottomUp(f) }
    if (val != null) val.walkBottomUp(f)
    f(this)
  }

  ** Tree walk
  override Void walkTopDown(|ANode| f)
  {
    if (typeRef != null) typeRef.walkTopDown(f)
    f(this)
    if (ast.meta != null) ast.meta.walkTopDown(f)
    if (declared != null) declared.each |x| { x.walkTopDown(f) }
    if (val != null) val.walkTopDown(f)
  }

  ** Debug dump
  override Void dump(OutStream out := Env.cur.out, Str indent := "")
  {
    indentMore := indent + "  "
    out.print(indent).print(name).print(": ")
    if (typeRef != null) out.print(typeRef).print(" ")
    if (ast.meta != null) ast.meta.dump(out, indentMore)
    if (declared != null)
    {
      out.printLine("{")
      declared.each |s|
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
  override CSpec? cbase() { ast.cbase }

  ** Parent spec or null if this is top-level spec
  override CSpec? cparent() { parent }

  ** Binding (set in LoadBindings)
  override SpecBinding binding() { ast.binding ?: throw NotReadyErr(qname) }

  ** Declared meta (set in Reify)
  override Dict metaOwn() { ast.metaOwn ?: throw NotReadyErr(qname) }

  ** Effective meta (set in InheritMeta)
  override Dict cmeta() { ast.cmeta ?: throw NotReadyErr(qname) }

  ** Effective meta has
  override Bool cmetaHas(Str name)
  {
    if (ast.cmeta != null) return ast.cmeta.has(name)
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
  [Str:CSpec]? cslotsRef { get { ast.cslots } set { ast.cslots = it } }

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
  [Str:CSpec]? enums() { ast.enums }

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
    if (ast.meta == null) return null
    x := ast.meta.get("of") as ASpecRef
    if (x == null) return null
    return (CSpec)x.deref
  }

  ** Extract 'ofs' list of type refs from AST model
  override once CSpec[]? cofs()
  {
    if (ast.meta == null) return null
    list := ast.meta.get("ofs") as ADict
    if (list == null) return null
    acc := CSpec[,]
    list.each |x|
    {
      Obj obj := ((ASpecRef)x).deref
      acc.add(obj)
    }
    return acc.ro
  }

  override Bool isNone() { isSys && name == "None" }

  override Bool isSelf() { isSys && name == "Self" }

  override Bool isEnum() { cbase != null && cbase.isSys && cbase.name == "Enum" }

  override Bool isAnd() { cbase != null && cbase.isSys && cbase.name == "And" }

  override Bool isOr() { cbase != null && cbase.isSys && cbase.name == "Or" }

  ** Inheritance flags computed in InheritSlots
  override Int flags { get { ast.flags }  set { ast.flags = it } }

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

  ** Mutable AST state
  ASpecState ast() { astRef.val }
  const Unsafe astRef


//////////////////////////////////////////////////////////////////////////
// Spec (unsupported)
//////////////////////////////////////////////////////////////////////////

  override SpecMap membersOwn() { throw UnsupportedErr() }

  override SpecMap slotsOwn() { throw UnsupportedErr() }

  override SpecMap globalsOwn() { throw UnsupportedErr() }

  override SpecMap globals() { throw UnsupportedErr() }

  override Bool isEmpty() { throw UnsupportedErr() }

  @Operator override Obj? get(Str n) { throw UnsupportedErr() }

  override Bool has(Str n) { throw UnsupportedErr() }

  override Bool missing(Str n) { throw UnsupportedErr() }

  override Void each(|Obj val, Str name| f) { throw UnsupportedErr() }

  override Obj? eachWhile(|Obj,Str->Obj?| f) { throw UnsupportedErr() }

  override Obj? trap(Str n, Obj?[]? a := null) { throw UnsupportedErr() }

  override SpecEnum enum() { throw UnsupportedErr() }

  override SpecFunc func() { throw UnsupportedErr() }

  override Void eachInherited(|Spec| f) { throw UnsupportedErr() }

  override Type fantomType() { throw UnsupportedErr() }

  override Int inheritanceDigest() {throw UnsupportedErr() }
}

**************************************************************************
** ASpecState
**************************************************************************

@Js
internal class ASpecState
{
  new make(ALib lib, ASpec? parent, SpecFlavor flavor)
  {
    this.lib    = lib
    this.parent = parent
    this.flavor = flavor
  }

  ALib lib { private set }
  ASpec? parent { private set }
  SpecFlavor flavor // TODO
  ASpecRef? typeRef
  Spec? base
CSpec? cbase() { base as CSpec }
  AScalar? val
  ADict? meta
  Dict? metaOwn
  Dict? cmeta
  [Str:ASpec]? declared
  [Str:CSpec]? cslots
  Int flags := -1
  [Str:CSpec]? enums
  SpecBinding? binding
  MSpecArgs? args
  Bool parsedCompound
  Bool parsedSyntheticRef
}

