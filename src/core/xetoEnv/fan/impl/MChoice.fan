//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Nov 2024  Brian Frank  Creation
//

using util
using xeto

**
** Implementation of SpecChoice and validation utilities
**
@Js
const final class MChoice : SpecChoice
{
  internal new make(LibNamespace ns, XetoSpec spec)
  {
    if (!spec.isChoice) throw UnsupportedErr("Spec is not choice: $spec.qname")
    this.ns   = ns
    this.spec = spec
  }

//////////////////////////////////////////////////////////////////////////
// SpecChoice
//////////////////////////////////////////////////////////////////////////

  const MNamespace ns

  override const XetoSpec spec

  override Spec type() { spec.type }

  override Bool isMaybe() { maybe(spec) }

  override Bool isMultiChoice() { multiChoice(spec) }

  override Spec[] selections(Dict instance, Bool checked := true)
  {
    selections := Spec[,]
    findSelections(ns, spec, instance, selections)
    if (checked) validate(spec, (Obj)selections) |err| { throw Err(err) }
    return selections
  }

  override Spec? selection(Dict instance, Bool checked := true)
  {
    selections(instance, checked).first
  }

//////////////////////////////////////////////////////////////////////////
// Compiler
//////////////////////////////////////////////////////////////////////////

  ** Validation called by XetoCompiler in CheckErrors
  static Void check(CNamespace ns, CSpec spec, Dict instance, |Str| onErr)
  {
    selections := CSpec[,]
    findSelections(ns, spec, instance, selections)
    validate(spec, selections, onErr)
  }

//////////////////////////////////////////////////////////////////////////
// Implemention (for both MNamespace and XetoCompiler)
//////////////////////////////////////////////////////////////////////////

  ** Find all the choice selections for instance
  static Void findSelections(CNamespace ns, CSpec spec, Dict instance, Obj[] acc)
  {
    // find all the matches first
    ns.eachSubtype(spec.ctype) |x|
    {
      if (!x.hasSlots) return
      if (xhasChoiceMarkers(instance, x)) acc.add(x)
    }

    // if we have more than one matches then strip supertypes such
    // that HotWater hides Water
    if (acc.size <= 1) return
    temp := XetoUtil.excludeSupertypes(acc)
    acc.clear.addAll(temp)
  }

  ** Validate given selections for an instance based on maybe/multi-choice flags
  static Void validate(CSpec spec, CSpec[] selections, |Str| onErr)
  {
    // if exactly one selection - always valid
    if (selections.size == 1) return

    // if zero selections - only valid if maybe type
    if (selections.size == 0)
    {
      if (maybe(spec)) return
      onErr("Instance missing required choice '$spec'")
      return
    }

    // multiple choices - only valid if multiChoice
    if (multiChoice(spec)) return
    onErr("Instance has conflicting choice '$spec': " + selections.join(", ") { it.name })
  }

  ** Return if instance has all the given marker tags of the given choice
  static Bool xhasChoiceMarkers(Dict instance, CSpec choice)
  {
    r := choice.cslotsWhile |slot|
    {
      instance.has(slot.name) ? null : "break"
    }
    return r == null
  }

  ** Is the given spec a maybe type
  static Bool maybe(CSpec spec) { spec.isMaybe }

  ** Does given spec define the multiChoice flag
  static Bool multiChoice(CSpec spec) { spec.cmeta.has("multiChoice") }
}

