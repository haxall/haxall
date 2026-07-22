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
** Ast is the top-level entry point for everything scanned from the
** working directory: the bound pods, their source files, and the
** @Gen tagged types.  All AST lookups are here.
**
internal class Ast
{
  new make(APod[] pods)
  {
    this.pods = pods
    this.byPodName = Str:APod[:].addList(pods) |p| { p.podName }
  }

  ** Pods matched to libs in scan order
  APod[] pods

  ** Lookup a pod by its Fantom pod name
  APod? pod(Str podName, Bool checked := true)
  {
    pod := byPodName[podName]
    if (pod != null) return pod
    if (checked) throw UnknownPodErr(podName)
    return null
  }

  ** Lookup the pod which is bound to the given lib name
  APod? podForLib(Str libName, Bool checked := true)
  {
    pod := pods.find |p| { p.libs.any |lib| { lib.name == libName } }
    if (pod != null) return pod
    if (checked) throw UnknownLibErr(libName)
    return null
  }

  ** Iterate every @Gen type in every pod
  Void eachType(|AType| f) { pods.each |pod| { pod.eachType(f) } }

  ** Total number of @Gen types
  Int numTypes() { pods.reduce(0) |Int acc, p->Int| { acc + p.numTypes } }

  Void dump(Console con := Console.cur)
  {
    pods.each |pod| { pod.dump(con) }
  }

  override Str toStr() { "Ast [$pods.size pods, $numTypes types]" }

  private Str:APod byPodName
}

