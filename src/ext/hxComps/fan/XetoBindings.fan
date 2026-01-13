//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Aug 2024  Matthew Giannini  Creation
//    7 Dec 2024  Brian Frank       Refactor from factory design
//

using xeto
using xetom

internal const class XetoBindingLoader : SpecBindingLoader
{
  override Void loadLib(SpecBindings acc, Str libName)
  {
    pod := typeof.pod
    acc.add(StatusBinding(pod.type("Status")))
    acc.add(StatusNumberBinding(pod.type("StatusNumber")))
    acc.add(StatusBoolBinding(pod.type("StatusBool")))
    acc.add(StatusStrBinding(pod.type("StatusStr")))
  }

  override SpecBinding? loadSpec(SpecBindings acc, SpecBindingInfo spec)
  {
    loadSpecReflect(acc, typeof.pod, spec)
  }
}

internal const class StatusBinding : DictBinding
{
  new make(Type type) : super("hx.comps::Status", type) {}
  override Dict decodeDict(Dict xeto) { MStatus(xeto) }
}

internal const class StatusBoolBinding : DictBinding
{
  new make(Type type) : super("hx.comps::StatusBool", type) {}
  override Dict decodeDict(Dict xeto) { MStatusBool(xeto) }
}

internal const class StatusNumberBinding : DictBinding
{
  new make(Type type) : super("hx.comps::StatusNumber", type) {}
  override Dict decodeDict(Dict xeto) { MStatusNumber(xeto) }
}

internal const class StatusStrBinding : DictBinding
{
  new make(Type type) : super("hx.comps::StatusStr", type) {}
  override Dict decodeDict(Dict xeto) { MStatusStr(xeto) }
}

