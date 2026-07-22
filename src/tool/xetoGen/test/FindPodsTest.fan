//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using xeto
using xetom

**
** FindPodsTest verifies pods are matched to libs via xeto.bindings.
** Assumes tests are run with the haxall repo as the working dir.
**
class FindPodsTest : Test
{

  Void testBindings()
  {
    ast := scan.ast

    // hxComps binds to hx.comps with explicit loader class
    pod := ast.pod("hxComps")
    verifyEq(pod.podName, "hxComps")
    verifyEq(pod.dir.name, "hxComps")
    verify(pod.dir.plus(`build.fan`).exists)
    verifyLibs(pod, ["hx.comps"])

    // hxTask binds to hx.task with pod loader
    verifyLibs(ast.pod("hxTask"), ["hx.task"])

    // hxd binds to multiple libs
    verifyLibs(ast.pod("hxd"), ["hx.hxd.his", "hx.hxd.proj", "hx.hxd.user"])

    // lookup pod by lib name
    verifySame(ast.podForLib("hx.comps"), pod)
    verifySame(ast.podForLib("hx.hxd.user"), ast.pod("hxd"))

    // bad lookups
    verifyEq(ast.pod("badPod", false), null)
    verifyErr(UnknownPodErr#) { ast.pod("badPod") }
    verifyEq(ast.podForLib("bad.lib", false), null)
    verifyErr(UnknownLibErr#) { ast.podForLib("bad.lib") }
  }

  Void testLibNames()
  {
    // explicit lib name filters to single pod
    ast := scan(["hx.comps"]).ast
    verifyEq(ast.pods.size, 1)
    verifyEq(ast.pods.first.podName, "hxComps")

    // multi-lib pod matched by any of its libs
    ast = scan(["hx.hxd.user"]).ast
    verifyEq(ast.pods.size, 1)
    verifyEq(ast.pods.first.podName, "hxd")

    // unmatched lib name is error
    verifyErr(XetoCompilerErr#) { scan(["bad.lib.name"]) }
  }

  ** Run the pipeline thru FindPods with silent logging
  private GenCompiler scan(Str[]? libNames := null)
  {
    c := GenCompiler
    {
      it.logger   = XetoLog.makeOutStream(Buf().out)
      it.libNames = libNames
    }
    c.run([FindPods()])
    return c
  }

  private Void verifyLibs(APod pod, Str[] expect)
  {
    verifyEq(pod.libs.map |lib->Str| { lib.name }, expect)
  }
}

