//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using util
using xeto

**
** Find @Gen tagged types in pod sources and resolve their specs
**
internal class FindTypes : Step
{
  override Void run()
  {
    info("FindTypes")
    pods.each |pod| { findTypes(pod) }
    bombIfErr
  }

  private Void findTypes(APod pod)
  {
    findInDir(pod, pod.dir)
    info("  $pod.podName [$pod.numTypes types]")
  }

  private Void findInDir(APod pod, File dir)
  {
    dir.list.each |f|
    {
      if (f.isDir) { findInDir(pod, f); return }
      if (f.ext != "fan" || f.name == "build.fan") return
      src := f.readAllStr
      if (!src.contains("@Gen")) return
      scanFile(pod, f, src)
    }
  }

  private Void scanFile(APod pod, File f, Str src)
  {
    try
    {
      afile := FileScanner(compiler, pod, f, src).scan
      if (afile.types.isEmpty) return
      afile.types.each |t| { resolve(t) }
      pod.files.add(afile)
    }
    catch (Err e) err("Cannot scan file", FileLoc(f.osPath), e)
  }

  ** Resolve type to its spec
  private Void resolve(AType t)
  {
    // explicit spec qname from meta
    explicit := t.gen.meta.get("spec")
    if (explicit != null)
    {
      t.spec = ns.spec(explicit.toStr, false)
      if (t.spec == null) err("Cannot resolve @Gen meta spec: $explicit", t.loc)
      return
    }

    // map type name to spec in pod's libs; M prefix for impl classes
    name := t.name
    if (name.size > 2 && name[0] == 'M' && name[1].isUpper && typeToSpec(t, name) == null)
      name = name[1..-1]
    t.spec = typeToSpec(t, name)
    if (t.spec == null) err("Cannot resolve spec for @Gen type: $t.name", t.loc)
  }

  ** Lookup type name in each of the pod's bound libs
  private Spec? typeToSpec(AType t, Str name)
  {
    t.file.pod.libs.eachWhile |lib| { lib.type(name, false) }
  }
}

