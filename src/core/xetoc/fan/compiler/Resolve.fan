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
    ast.walk |x| { if (x.isRef) resolveRef(x) }

    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Depends
//////////////////////////////////////////////////////////////////////////

  private Void resolveDepends()
  {
    // sys has no dependencies
    if (isSys) return

    // process each depends from ProcessPragma step
    compiler.depends.each |depend|
    {
      resolveDepend(depend)
    }
  }

  private Void resolveDepend(MLibDepend d)
  {
    // resolve the library from environment
    lib := env.registry.resolve(compiler, d.qname)
    if (lib == null)
      return err("Depend lib '$d.qname' not installed", d.loc)

    // validate our version constraints
    if (!d.versions.contains(lib.version))
      return err("Depend lib '$d.qname' version '$lib.version' is incompatible with '$d.versions'", d.loc)

    // register the library into our depends map
    depends.add(lib.name, lib)
  }

//////////////////////////////////////////////////////////////////////////
// Resolve Ref
//////////////////////////////////////////////////////////////////////////

  private Void resolveRef(ASpecRef ref)
  {
    // short circuit if null or already resolved
    if (ref.isResolved) return

    // don't support this yet
    if (ref.name.size > 1) throw Err("TODO: path name: $ref")

    // resolve qualified name
    n := ref.name
    if (n.isQualified) return resolveQualified(ref)

    // match to name within this AST which trumps depends
    if (isLib)
    {
      spec := lib.spec(n.name)
      if (spec != null)
      {
        ref.resolve(spec)
        return
      }
    }

    // match to external dependencies
    matches := XetoSpec[,]
    depends.each |lib| { matches.addNotNull(lib.type(n.name, false)) }
    if (matches.isEmpty)
      err("Unresolved type: $n", ref.loc)
    else if (matches.size > 1)
      err("Ambiguous type: $n $matches", ref.loc)
    else
      ref.resolve(matches.first)
  }

  private Void resolveQualified(ASpecRef ref)
  {
    // if in my own lib
    n := ref.name
    if (n.lib == compiler.libName)
    {
      spec := lib.spec(n.name)
      if (spec == null) return err("Spec '$n' not found in lib", ref.loc)
      ref.resolve(spec)
      return
    }

    // resolve from dependent lib
    XetoLib? lib := depends[n.lib]
    if (lib == null) return err("Spec lib '$n' is not included in depends", ref.loc)

    // resolve in lib
    type := lib.type(n.name, false)
    if (type == null) return err("Unresolved spec '$n' in lib", ref.loc)
    ref.resolve((CSpec)type)
  }

  private Str:XetoLib depends := [:]
}