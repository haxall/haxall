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
    acc.add(AxonSrcBinding(pod.type("AxonSrc")))
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
internal const class AxonSrcBinding : ScalarBinding
{
  new make(Type type) : super("axon::AxonSrc", type) {}
  override Obj? decodeScalar(Str s, Bool checked := true) { AxonSrc(s) }
}

