//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//   25 Jan 2023  Brian Frank  Redesign from proto
//

using util
using xeto
using xetom

**
** Resolve all type refs
**
@Js
internal class Resolve : Step
{
  override Void run()
  {
    // resolve the dependencies
    resolveDepends
    bombIfErr

    // resolve the sys types (we might use them in later steps)
    sys.each |x| { resolveRef(x) }

    // resolve the ARefs
    ast.walkBottomUp |x| { resolveNode(x) }

    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Depends
//////////////////////////////////////////////////////////////////////////

  private Void resolveDepends()
  {
    // init namespace map
    depends.libs = Str:XetoLib[:]

    // sys has no dependencies
    if (isSys) return

    // process each depends from ProcessPragma step
    depends.list.each |depend|
    {
      resolveDepend(depend)
    }
  }

  private XetoLib? resolveDepend(MLibDepend d)
  {
    // resolve the library from namespace
    libStatus := ns.libStatus(d.name, false)
    if (libStatus == null)
    {
      err("Depend lib '$d.name' not in namespace", d.loc)
      return null
    }

    // if we could not compile dependency
    if (libStatus.isErr)
    {
      msg := ns.libErr(d.name)
      err("Depend lib '$d.name' could not be compiled: $msg", d.loc)
      return null
    }

    // resolve the library from namespace
    lib := ns.lib(d.name)

    // validate our version constraints
    if (!d.versions.contains(lib.version))
    {
      err("Depend lib '$d.name' version '$lib.version' is incompatible with '$d.versions'", d.loc)
      return null
    }

    // register the library into our depends map
    depends.libs.add(lib.name, lib)
    return lib
  }

//////////////////////////////////////////////////////////////////////////
// Resolve Node
//////////////////////////////////////////////////////////////////////////

  private Void resolveNode(ANode node)
  {
    if (node.nodeType === ANodeType.specRef) return resolveRef(node)
    if (node.nodeType === ANodeType.dataRef) return resolveRef(node)
    if (node.nodeType === ANodeType.spec) return resolveSpec(node)
  }

  private Void resolveSpec(ASpec spec)
  {
    // spec meta "val" handling
    val := spec.val
    if (val != null)
    {
      // default value is implied to be the meta "val" tag
      spec.metaSet("val", val)
    }
    else
    {
      // check if "val" was defined inside the meta
      val = spec.metaGet("val")
    }

    // the value is inferred to the type of the spec itself
    if (val != null && val.typeRef == null)
      val.typeRef = toSelfRef(spec, val.loc)
  }

  private ASpecRef? toSelfRef(ASpec spec, FileLoc loc)
  {
    if (spec.isTop)
    {
      ref := ASpecRef(loc, ASimpleName(lib.name, spec.name))
      resolve(ref, spec)
      return ref
    }
    else
    {
      return spec.typeRef
    }
  }

//////////////////////////////////////////////////////////////////////////
// Resolve Data/Spec Ref
//////////////////////////////////////////////////////////////////////////

  private Void resolveRef(ARef ref)
  {
    // short circuit if null or already resolved
    if (ref.isResolved) return

    // don't support this yet
    n := ref.name
    if (n.size > 1)
    {
      // don't support dotted notation for instances
      if (ref isnot ASpecRef)
      {
        err("Dotted instance ref not supported", ref.loc)
      }
      else
      {
        resolveDotted(ref)
      }
      return
    }

    // resolve qualified name
    if (n.isQualified) return resolveQualified(ref)

    // match to name within this AST which trumps depends
    x := resolveInAst(ref, n.name)
    if (x != null)
    {
      resolve(ref, x)
      return
    }

    // match to external dependencies
    matches := Obj[,]
    depends.libs.each |d| { matches.addNotNull(resolveInDepend(ref, n.name, d)) }
    if (matches.isEmpty)
    {
      if (allowUnresolved) return
      err("Unresolved $ref.what: $n", ref.loc)
    }
    else if (matches.size > 1)
    {
      err("Ambiguous $ref.what: $n $matches", ref.loc)
    }
    else
    {
      resolve(ref, matches.first)
    }
  }

  private Void resolveDotted(ASpecRef ref)
  {
    // resolve the base spec
    n := ref.name
    baseRef := ASpecRef(ref.loc, ASimpleName(n.lib, n.nameAt(0)))
    resolveRef(baseRef)
    if (!baseRef.isResolved) return

    // not walk the names
    base := baseRef.deref
    Spec? p := base
    for (i := 1; i<n.size; ++i)
    {
      // if the base is an AST spec within my own lib, then this is
      // super tricky because we have not inherited slots yet; so for
      // now we just don't support it
      if (p.isAst) return err("Dotted spec name within lib not supported: $n", ref.loc)

      // resolve slot in the current spec
      slotName := n.nameAt(i)
      p = base.slot(slotName, false)
      if (p == null) return err("Unresolved dotted spec name '$n'", ref.loc)
    }

    // success!
    resolve(ref, (CNode)p)
  }

  private Void resolveQualified(ARef ref)
  {
    // if in my own lib
    n := ref.name
    if (n.lib == compiler.libName)
    {
      x := resolveInAst(ref, n.name)
      if (x == null)
      {
        if (allowUnresolved) return
        return err("$ref.what.capitalize '$n' not found in lib", ref.loc)
      }
      resolve(ref, x)
      return
    }

    // resolve from dependent lib
    XetoLib? depend := depends.libs[n.lib]
    if (depend == null)
    {
      // libs must have explicit depends, but we allow lazy depends in data files
      if (isLib) return err("$ref.what.capitalize lib '$n' is not included in depends", ref.loc)
      depend = resolveDepend(MLibDepend(n.lib, MLibDependVersions.wildcard, ref.loc))
      if (depend == null) return
    }

    // resolve in dependency
    x := resolveInDepend(ref, n.name, depend)
    if (x == null)
    {
      if (allowUnresolved) return
      return err("Unresolved $ref.what '$n' in lib", ref.loc)
    }
    resolve(ref, x)
  }

  private Obj? resolveInAst(ARef ref, Str name)
  {
    ref.nodeType === ANodeType.specRef ?
      compiler.lib?.ast?.type(name) :
      ast.ast.instance(name)
  }

  private Obj? resolveInDepend(ARef ref, Str name, XetoLib depend)
  {
    ref.nodeType === ANodeType.specRef ?
      depend.type(name, false) :
      wrapInstance(depend.instance(name, false))
  }

  ** Wrap instance from dependency
  private CInstance? wrapInstance(Dict? dict)
  {
    if (dict == null) return null
    return CInstanceWrap(dict, ns.specOf(dict))
  }

  ** Allow unresolved refs
  private Bool allowUnresolved()
  {
    compiler.externRefs || mode.isAst
  }

  ** Choke point for calling ARef.resolve
  private Void resolve(ARef ref, CNode node)
  {
    // special handling for sys::This
    if (!isSys && node === ns.sys.self && isData)
      node = compiler.opts["this"] as CNode ?: throw err("Must set 'this' in opts", ref.loc)

    ref.resolve(node)
  }
}

