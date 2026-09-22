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
      validator.validateNode(data.root)

    // boom!
    bombIfErr
  }

  ** Validate all the instances and spec meta in the lib
  private Void validateLib(CompileValidator validator)
  {
    lib.ast.instances.each |x| { validator.validateNode(x) }
    lib.tops.each |x| { validateSpecMeta(validator, x) }
  }

  ** Validate spec meta values against their meta member specs; a
  ** value with no member checks against its own inferred type
  private Void validateSpecMeta(CompileValidator validator, ASpec x)
  {
    x.ast.meta?.each |v, n|
    {
      if (v.isNone) return // None clears an inherited tag, nothing to check
      member := metas.get(n, false)
      // This typed meta such as minVal and val is not checked: the
      // idiom of plain numerics for custom scalar ranges means the
      // value type never matches the resolved self type
      if (member != null && member.type.isThis) return
      validator.validateNode(v, member)
    }
    x.declared?.each |slot| { validateSpecMeta(validator, slot) }
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
    : super(c.ns, NilXetoContext.val, toOpts(c), rules)
  {
    this.compiler = c
    this.lib      = c.mode.isLib ? c.lib.asm : null
    this.prefix   = lib == null ? null : lib.name + "::"
  }

  ** Compile time opts: skip mixin composition since specx enumerates a
  ** namespace still under construction; skip missing slots since
  ** instances inherit from their spec; skip unresolved refs since the
  ** Resolve step already settled existence.  Companion values originate
  ** from haystack data such as comp saves, so they validate at
  ** haystack fidelity.
  private static Dict toOpts(MXetoCompiler c)
  {
    Etc.dictx("ignoreMixins", Marker.val,
              "ignoreMissingSlots", Marker.val,
              "ignoreUnresolvedRefs", Marker.val,
              "haystack", Marker.fromBool(c.isCompanion))
  }

  ** Validate one AST node so items can map their locs back thru it.
  ** The engine walks values reified to a dict, list, or scalar; a
  ** specRef, dataRef, or factory value such as Grid has no checks.
  ** The spec to check against defaults to the node's own type.
  Void validateNode(AData node, Spec? spec := null)
  {
    // skip specRefs (a Spec asm is a Dict) and anything not reified
    // to a dict, list, or scalar such as Grid or Fantom bound values
    if (node.nodeType === ANodeType.specRef) return
    if (node.nodeType !== ANodeType.scalar && node.asm isnot Dict && node.asm isnot List) return

    this.curNode = node
    validate(node.asm, spec?.asm ?: node.type.asm, node.loc)
    this.curNode = null
  }

  ** Route each item into the compiler err/warn streams as it emits
  override Void onEmit(MValidateItem item)
  {
    if (item.level.isErr)
      compiler.err(item.dis, itemLoc(item))
    else
      compiler.warn(item.dis, itemLoc(item))
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


  override Spec? resolveSpec(Str qname)
  {
    n := ownName(qname)
    if (n == null) return super.resolveSpec(qname)
    return XetoUtil.libSpec(lib, n)
  }

  override Dict? resolveInstance(Str qname)
  {
    n := ownName(qname)
    if (n == null) return super.resolveInstance(qname)
    return lib.instance(n, false)
  }

  ** Type enumeration such as choice subtype discovery must see the
  ** lib under compile, so we are our own CNamespace
  override CNamespace cns() { this }

  ** Enumerate the assembled lib under compile plus the loaded libs
  ** of the namespace
  override Void eachTypeThatIs(Spec type, |Spec| f)
  {
    lib?.types?.each |x| { if (x.isa(type)) f(x) }
    XetoUtil.eachLoadedTypeThatIs(ns, type, f)
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

