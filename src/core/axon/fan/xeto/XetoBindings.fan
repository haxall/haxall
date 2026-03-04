//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Mar 2026  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using concurrent

@Js
internal const class XetoBindingLoader : SpecBindingLoader
{
  override Void loadLib(SpecBindings acc, Str libName)
  {
    pod := typeof.pod
    acc.add(AxonExprBinding(pod.type("AxonExpr")))
  }

  override SpecBinding? loadSpec(SpecBindings acc, SpecBindingInfo spec)
  {
    loadSpecReflect(acc, typeof.pod, spec)
  }

  override Thunk loadThunk(Spec spec)
  {
    ThunkFactory.cur.create(spec, typeof.pod)
  }
}

@Js
internal const class AxonExprBinding : ScalarBinding
{
  new make(Type type) : super("axon::AxonExpr", type) {}
  override Obj? decodeScalar(Str s, Bool checked := true) { AxonExpr(s, true) }
}

