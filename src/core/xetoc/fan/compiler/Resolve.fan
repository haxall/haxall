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
using xetoEnv

**
** Resolve all type refs
**
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
    // resolve the library from environment
    lib := env.registry.resolve(compiler, d.name)
    if (lib == null)
    {
      err("Depend lib '$d.name' not installed", d.loc)
      return null
    }

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
    // if top level spec has a default value, then its scalar
    // type is the spec itself and its implicitly a meta "def" tag
    val := spec.val
    if (val != null && !val.isAsm)
    {
      if (val.typeRef == null)
      {
        ASpecRef? ref
        if (spec.isTop)
        {
          ref = ASpecRef(val.loc, ASimpleName(lib.name, spec.name))
          ref.resolve(spec)
        }
        else
        {
          ref = spec.typeRef
        }
        val.typeRef = ref
      }
      spec.metaSet("val", val)
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
    if (ref.name.size > 1) throw Err("TODO: path name: $ref")

    // resolve qualified name
    n := ref.name
    if (n.isQualified) return resolveQualified(ref)

    // match to name within this AST which trumps depends
    x := resolveInAst(ref, n.name)
    if (x != null)
    {
      ref.resolve(x)
      return
    }

    // match to external dependencies
    matches := Obj[,]
    depends.libs.each |d| { matches.addNotNull(resolveInDepend(ref, n.name, d)) }
    if (matches.isEmpty)
    {
      if (compiler.externRefs) return
      err("Unresolved $ref.what: $n", ref.loc)
    }
    else if (matches.size > 1)
    {
      err("Ambiguous $ref.what: $n $matches", ref.loc)
    }
    else
    {
      ref.resolve(matches.first)
    }
  }

  private Void resolveQualified(ARef ref)
  {
    // if in my own lib
    n := ref.name
    if (n.lib == compiler.libName)
    {
      x := resolveInAst(ref, n.name)
      if (x == null) return err("$ref.what.capitalize '$n' not found in lib", ref.loc)
      ref.resolve(x)
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
      if (compiler.externRefs) return
      return err("Unresolved $ref.what '$n' in lib", ref.loc)
    }
    ref.resolve(x)
  }

  private Obj? resolveInAst(ARef ref, Str name)
  {
    ref.nodeType === ANodeType.specRef ?
      compiler.lib?.top(name) :
      ast.instance(name)
  }

  private Obj? resolveInDepend(ARef ref, Str name, XetoLib depend)
  {
    ref.nodeType === ANodeType.specRef ?
      depend.type(name, false) :
      CInstance.wrap(env, depend.instance(name, false))
  }


}

