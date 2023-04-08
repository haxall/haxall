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

    // resolve the sys types (we might use them in later steps)
    sys.each |x| { resolveRef(x) }

    // resolve the ARefs
    ast.walk |x|
    {
      if (x is ARef) resolveRef(x)
    }

    bombIfErr
  }

//////////////////////////////////////////////////////////////////////////
// Depends
//////////////////////////////////////////////////////////////////////////

  private Void resolveDepends()
  {
    // sys has no dependencies
    if (isSys) return

    // import dependencies from pragma
    astDepends := pragma?.meta?.slot("depends")
    if (astDepends != null)
    {
      astDepends.slots.each |astDepend| { resolveDepend(astDepend) }
    }

    // if not specified, assume just sys
    if (depends.isEmpty)
    {
      if (isLib) err("Must specify 'sys' in depends", pragma.loc)
      depends["sys"] = env.lib("sys")
      return
    }
  }

  private Void resolveDepend(AObj obj)
  {
    // get library name from depend formattd as "{lib:<qname>}"
    loc := obj.loc
    libName := (obj.slot("lib")?.val as AScalar)?.str
    if (libName == null) return err("Depend missing lib name", loc)

    // resolve the library from environment
    lib := env.lib(libName, false)
    if (lib == null) return err("Depend lib '$libName' not installed", loc)

    // register the library into our depends map
    if (depends[libName] != null) return err("Duplicate depend '$libName'", loc)
    depends[libName] = lib
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