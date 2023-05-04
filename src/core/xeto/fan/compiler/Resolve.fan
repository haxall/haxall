//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2022  Brian Frank  Creation
//   25 Jan 2023  Brian Frank  Redesign from proto
//

using util
using data

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
    walkRefs(ast) |x| { resolveRef(x) }

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

  private Void resolveDepend(XetoLibDepend d)
  {
    // resolve the library from environment
    lib := env.registry.resolve(compiler, d.qname)
    if (lib == null)
      return err("Depend lib '$d.qname' not installed", d.loc)

    // validate our version constraints
    if (!d.versions.contains(lib.version))
      return err("Depend lib '$d.qname' version '$lib.version' is incompatible with '$d.versions'", d.loc)

    // register the library into our depends map
    depends.add(lib.qname, lib)
  }

//////////////////////////////////////////////////////////////////////////
// Resolve Ref
//////////////////////////////////////////////////////////////////////////

  private Void resolveRef(ARef ref)
  {
    // short circuit if null or already resolved
    if (ref.isResolved) return

    // resolve qualified name
    n := ref.name
    if (n.isQualified) return resolveQualified(ref)

    // match to name within this AST which trumps depends
    if (isLib)
    {
      type := lib.slot(n.name) as AType
      if (type != null)
      {
        ref.resolve(type)
        return
      }
    }

    // match to external dependencies
    matches := XetoSpec[,]
    depends.each |lib| { matches.addNotNull(lib.slotOwn(n.name, false)) }
    if (matches.isEmpty)
      err("Unresolved type: $n", ref.loc)
    else if (matches.size > 1)
      err("Ambiguous type: $n $matches", ref.loc)
    else
      ref.resolve(matches.first)
  }

  private Void resolveQualified(ARef ref)
  {
    // if in my own lib
    n := ref.name
    if (n.lib == compiler.qname)
    {
      type := lib.slot(n.name) as AType
      if (type == null) return err("Spec '$n' not found in lib", ref.loc)
      ref.resolve(type)
      return
    }

    // resolve from dependent lib
    XetoLib? lib := depends[n.lib]
    if (lib == null) return err("Spec lib '$n' is not included in depends", ref.loc)

    // resolve in lib
    type := lib.libType(n.name, false)
    if (type == null) return err("Unresolved spec '$n' in lib", ref.loc)
    ref.resolve((CSpec)type)
  }

  private Str:XetoLib depends := [:]
}