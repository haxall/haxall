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
** Find pods under the working dir source tree bound to xeto libs
** via the "xeto.bindings" index props:
**
**   // bind pod to lib using pod loader
**   index = ["xeto.bindings": "libName"]
**
**   // bind pod to lib using specific SpecBindingLoader class
**   index = ["xeto.bindings": "libName ion::XetoBindingLoader"]
**
**   // bind pod to multiple libs
**   index = ["xeto.bindings": ["lib.one", "lib.two"]]
**
internal class FindPods : Step
{
  override Void run()
  {
    workDir := Env.cur.workDir
    info("FindPods [$workDir.osPath]")
    initPodToLibs
    walkDirs
    check
    bombIfErr
  }

  private Void initPodToLibs()
  {
    // build pod name -> lib names from index props (pods must be compiled)
    Env.cur.indexByPodName("xeto.bindings").each |list, podName|
    {
      podToLibs[podName] = list.map |str->Str| { str.split.first }
    }
  }

  private Void walkDirs()
  {
    acc := APod[,]
    Env.cur.workDir.plus(`src/`).walk |f|
    {
      if (!isPodDirMatch(f)) return
      acc.addNotNull(initPod(f))
    }
    compiler.ast = Ast(acc)
  }

  private Bool isPodDirMatch(File f)
  {
    if (!f.isDir) return false

    libNames := podToLibs[f.name]
    if (libNames == null) return false

    // build.fan must be a BuildPod; a BuildGroup dir may
    // share its name with a pod (studio src/ion vs src/ion/ion)
    if (!isBuildPod(f.plus(`build.fan`))) return false

    if (compiler.libNames == null) return true
    return libNames.any |n| { compiler.libNames.contains(n) }
  }

  ** Pattern to check for a BuildPod file
  private static const Regex buildPattern := Regex<|Build\s+:\s+BuildPod\b|>

  ** Is this build.fan file a BuildPod (instead of a BuildGroup)
  private Bool isBuildPod(File f)
  {
    if (!f.exists) return false
    return f.readAllLines.any { buildPattern.matcher(it).find }
  }

  private APod? initPod(File podDir)
  {
    libs := Lib[,]
    podToLibs.getChecked(podDir.name).each |n|
    {
      lib := ns.lib(n, false)
      if (lib == null) warn("Pod $podDir.name binding to uninstalled lib: $n", FileLoc(podDir.osPath))
      else libs.add(lib)
    }
    if (libs.isEmpty) return null
    return APod(libs, podDir.name, podDir)
  }

  private Void check()
  {
    // verify explicitly specified libs were all matched
    if (compiler.libNames == null) return
    compiler.libNames.each |libName|
    {
      if (compiler.ast.podForLib(libName, false) == null)
        err("Lib not matched to pod in working dir: $libName", FileLoc.unknown)
    }
  }

  private Str:Str[] podToLibs := [:]
}

