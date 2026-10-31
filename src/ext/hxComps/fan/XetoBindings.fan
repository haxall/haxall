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

**
** Decodes a StatusBool dict, and also a bare "true" or "false" scalar
** as that value with status ok.  The scalar decode applies to every
** StatusBool slot, and lets a space that saved Latch.clock as a plain
** Bool load.  Extends SpecBinding because DictBinding.decodeScalar is
** final.
**
internal const class StatusBoolBinding : SpecBinding
{
  new make(Type type) { this.type = type }
  override Str spec() { "hx.comps::StatusBool" }
  const override Type type
  override Bool isScalar() { false }
  override Bool isDict() { true }
  override Bool isInheritable() { true }
  override Dict decodeDict(Dict xeto) { MStatusBool(xeto) }
  override Obj? decodeScalar(Str xeto, Bool checked := true)
  {
    b := Bool.fromStr(xeto, false)
    if (b != null) return StatusBool(b, Status.ok)
    if (checked) throw ParseErr("Invalid StatusBool scalar: $xeto.toCode")
    return null
  }
  override Str encodeScalar(Obj val) { throw UnsupportedErr(spec) }
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

