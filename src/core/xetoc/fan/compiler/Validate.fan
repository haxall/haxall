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
** data and the specs, using the rules of the dependency chain and of
** the lib under compile.  Runs after Assemble so instances and specs
** are their real implementations.
**
@Js
internal class Validate : Step
{
  override Void run()
  {
    // skip sys bootstrapping
    if (ns == null || isSys) return

    // rules from the depends closure and the lib under compile;
    // build-only rules run only when building a xetolib
    libs := isLib ? depends.all.dup.add(lib.asm) : depends.all
    rules := ValidateRules.makeLibs(ns, libs, compiler.isBuild)

    // init validator with rules
    validator := CompileValidator(compiler, rules)

    // a lib is its instances and its specs; data is one value
    if (isLib)
    {
      lib.ast.instances.each |x| { validator.validateData(x) }
      lib.tops.each |x| { validator.validateSpec(x) }
    }
    else
    {
      validator.validateData(data.root)
    }

    // boom!
    bombIfErr
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
internal class CompileValidator : Validator
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

//////////////////////////////////////////////////////////////////////////
// Entry Points
//////////////////////////////////////////////////////////////////////////

  ** Validate an instance or a data root against its own spec.  A
  ** dict is the subject and the engine walks its tags
  Void validateData(AData x)
  {
    if (!isReified(x)) return
    this.curNode = x
    validate(x.asm, x.type.asm, x.loc)
    this.curNode = null
  }

  ** Validate a spec and the slots it declares.  A spec is a dict
  ** whose tags are its meta, so it is validated like an instance:
  ** it is the subject, checked against sys::Spec
  Void validateSpec(ASpec x)
  {
    this.curNode = x.ast.meta
    validate(x.asm, ns.sys.spec, x.loc)
    this.curNode = null

    x.declared?.each |slot| { validateSpec(slot) }
  }

  ** The engine walks values reified to a dict, list, or scalar.  A
  ** specRef (a Spec asm is a Dict), dataRef, or factory value such
  ** as Grid or a Fantom bound value has no checks
  private static Bool isReified(AData x)
  {
    if (x.nodeType === ANodeType.specRef) return false
    return x.nodeType === ANodeType.scalar || x.asm is Dict || x.asm is List
  }

//////////////////////////////////////////////////////////////////////////
// Engine Hooks
//////////////////////////////////////////////////////////////////////////

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

  ** The meta tags of a spec are members of sys::Spec by mixin, which
  ** the compiler has already composed from the depends closure
  override Spec? resolveMember(Spec spec, Str name)
  {
    spec === ns.sys.spec ? compiler.metas.get(name, false)?.asm : super.resolveMember(spec, name)
  }

  ** Type enumeration such as choice subtype discovery is scoped to
  ** the depends closure plus the lib under compile
  override CNamespace cns() { compiler.cns }

  ** Name within the lib under compile if qname targets it, else null
  private Str? ownName(Str qname)
  {
    prefix != null && qname.startsWith(prefix) ? qname[prefix.size..-1] : null
  }

  private MXetoCompiler compiler // compiler for err/warn reporting
  private XetoLib? lib      // lib under compile or null in data mode
  private const Str? prefix // "libName::" or null in data mode
  private AData? curNode    // AST of the subject, so itemLoc can walk an item's slot path
}

