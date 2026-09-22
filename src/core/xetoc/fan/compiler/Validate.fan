//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetom

**
** Validate runs the xetom validation engine over the reified instance
** data using only rules from the dependency chain.  Rules defined by
** the lib under compile never run at compile time.  Runs after Assemble
** so instances and specs are their real implementations.
**
@Js
internal class Validate : Step
{
  override Void run()
  {
    // skip sys bootstrapping
    if (ns == null || isSys) return

    // rules for libs in scope
    rules := ValidateRules.makeLibs(ns, depends.libs.vals)

    // init validator with rules
    validator := CompileValidator(compiler, rules)

    // validate lib or data
    if (isLib)
      validateLib(validator)
    else
      validateData(validator)

    // boom!
    bombIfErr
  }

  ** Validate all the instances in the lib
  private Void validateLib(CompileValidator validator)
  {
    lib.ast.instances.each |x| { validator.validateNode(x) }
  }

  ** Validate root value of a data compile
  private Void validateData(CompileValidator validator)
  {
    root := data.root
    if (runValidateData(root))
      validator.validateNode(root)
  }

  ** We only validate scalars, dicts, and lists; not a ASpecRef or Grids
  private Bool runValidateData(AData root)
  {
    if (root.nodeType === ANodeType.scalar ) return true
    if (root.nodeType === ANodeType.dict) return root.asm is Dict || root.asm is List
    return false
  }
}

**************************************************************************
** CompileValidator
**************************************************************************

**
** CompileValidator overlays the lib under compile, which is not in the
** namespace yet, over the engine's qname resolution.
**
@Js
internal class CompileValidator : Validator, CNamespace
{
  new make(MXetoCompiler c, ValidateRules rules)
    : super(c.ns, NilXetoContext.val, compileOpts, rules)
  {
    this.compiler = c
    this.lib      = c.mode.isLib ? c.lib.asm : null
    this.prefix   = lib == null ? null : lib.name + "::"
  }

  ** Validate one AST node so items can map their locs back thru it
  Void validateNode(AData node)
  {
    this.curNode = node
    validate(node.asm, node.type.asm, node.loc)
    this.curNode = null
  }

  ** Route each item into the compiler err/warn streams as it emits
  override Void onEmit(MValidateItem item)
  {
    msg := item.slot != null ? "Slot '$item.slot': $item.msg" : item.msg
    if (item.level.isErr)
      compiler.err(msg, itemLoc(item))
    else
      compiler.warn(msg, itemLoc(item))
  }

  ** Refine item loc by walking its slot path down the current AST
  ** node; list items reify at their auto names.  Falls back to the
  ** deepest node found when the path leaves the AST.
  private FileLoc itemLoc(MValidateItem item)
  {
    AData? node := curNode
    loc := node?.loc ?: item.loc
    item.slot?.split('.')?.each |n|
    {
      d := node as ADict
      node = d?.get(n) ?: (n[0].isDigit ? d?.get("_" + n) : null)
      if (node != null) loc = node.loc
    }
    return loc
  }

  ** Unresolved refs are externs already settled by Resolve; missing
  ** slots are not checked because instances inherit from their spec
  private static const Dict compileOpts :=
    Etc.dict2("ignoreUnresolvedRefs", Marker.val, "ignoreMissingSlots", Marker.val)

  override Spec? resolveSpec(Str qname)
  {
    n := ownName(qname)
    if (n == null) return super.resolveSpec(qname)
    names := n.split('.', false)
    spec := lib.spec(names.first, false)
    for (i:=1; spec != null && i<names.size; ++i) spec = spec.member(names[i], false)
    return spec
  }

  override Dict? resolveInstance(Str qname)
  {
    n := ownName(qname)
    if (n == null) return super.resolveInstance(qname)
    return lib.instance(n, false)
  }

  override Spec? specOf(Obj? val)
  {
    // own lib dicts and scalars resolve their spec thru the overlay
    scalar := val as Scalar
    if (scalar != null && ownName(scalar.qname) != null) return resolveSpec(scalar.qname)
    specRef := (val as Dict)?.get("spec") as Ref
    if (specRef != null && ownName(specRef.id) != null) return resolveSpec(specRef.id)
    return super.specOf(val) ?: bindingSpecOf(val)
  }

  ** Fantom bound values whose binding spec qname lives in the lib under
  ** compile; mirrors the type hierarchy walk of MNamespace.specOf
  private Spec? bindingSpecOf(Obj? val)
  {
    if (val == null) return null
    bindings := SpecBindings.cur
    for (Type? p := val.typeof; p.base != null; p = p.base)
    {
      b := bindings.forType(p) ?: p.mixins.eachWhile |m->SpecBinding?| { bindings.forType(m) }
      if (b != null) return resolveSpec(((SpecBinding)b).spec)
    }
    return null
  }

  ** Cross-lib mixins compose at runtime only; the lib's own mixin
  ** meta is already folded into its specs by the MixinMeta step
  override Spec specx(Spec spec) { spec }

  ** Type enumeration such as choice subtype discovery must see the
  ** lib under compile, so we are our own CNamespace
  override CNamespace cns() { this }

  ** Enumerate the assembled lib under compile plus the loaded libs of
  ** the namespace; the namespace may still be under construction, so
  ** like ANamespace we only touch libs that resolve as loaded
  override Void eachTypeThatIs(Spec type, |Spec| f)
  {
    lib?.types?.each |x| { if (x.isa(type)) f(x) }
    ns.versions.each |v|
    {
      l := ns.lib(v.name, false)
      if (l == null || l === lib) return
      l.types.each |x| { if (x.isa(type)) f(x) }
    }
  }

  ** Name within the lib under compile if qname targets it, else null
  private Str? ownName(Str qname)
  {
    prefix != null && qname.startsWith(prefix) ? qname[prefix.size..-1] : null
  }

  private MXetoCompiler compiler // compiler for err/warn reporting
  private XetoLib? lib      // lib under compile or null in data mode
  private const Str? prefix // "libName::" or null in data mode
  private AData? curNode    // AST node under validation for itemLoc
}

