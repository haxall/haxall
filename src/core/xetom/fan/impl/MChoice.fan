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
  internal new make(Namespace ns, XetoSpec spec)
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

  override Str toStr() { spec.qname }

  override Bool isMaybe() { maybe(spec) }

  override Bool isMultiChoice() { multiChoice(spec) }

  override Spec[] selections(Dict instance, Bool checked := true)
  {
    selections := Spec[,]
    doFindSelections(choiceSubtypes, instance, selections)
    if (checked) validate(spec, (Obj)selections) |err| { throw Err(err) }
    return selections
  }

  override Spec[] subtypes(Spec base := spec)
  {
    acc := Spec[,]
    choiceSubtypes.each |CSpec cx|
    {
      x := (Spec)cx
      if (x.base === base) acc.add(x)
    }
    return acc
  }

  override Spec? selection(Dict instance, Bool checked := true)
  {
    // if checked then find all selections and validate;
    // otherwise we can optimize to just find first match
    if (checked)
      return selections(instance, checked).first
    else
      return doFindSelection(choiceSubtypes, instance) as Spec
  }

  ** Cache the choice subtype computation because its really expensive
  private once CSpec[] choiceSubtypes()
  {
    findChoiceSubtypes(ns, spec).toImmutable
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

  ** Get all the choice subtypes to use for checking
  static Obj[] findChoiceSubtypes(CNamespace ns, CSpec spec)
  {
    acc := Obj[,]
    ns.ceachTypeThatIs(spec.ctype) |x|
    {
      if (!x.isChoice) return
      acc.add(x)
    }
    return acc
  }

  ** Find all the choice selections for instance
  static Void findSelections(CNamespace ns, CSpec spec, Dict instance, Obj[] acc)
  {
    subtypes := findChoiceSubtypes(ns, spec)
    return doFindSelections(subtypes, instance, acc)
  }

  ** Find first match selection. This is an optimization used used for
  ** an unchecked selection that lets us avoid a bunch of extra computation
  static CSpec? doFindSelection(CSpec[] subtypes, Dict instance)
  {
    subtypes.find |x|
    {
      hasChoiceMarkers(instance, x)
    }
  }

  ** Find all the choice selections for instance
  static Void doFindSelections(CSpec[] subtypes, Dict instance, Obj[] acc)
  {
    // find all the matches first
    subtypes.each |x|
    {
      if (hasChoiceMarkers(instance, x)) acc.add(x)
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
      onErr("Missing required choice '$spec.ctype'")
      return
    }

    // multiple choices - only valid if multiChoice
    if (multiChoice(spec)) return

    // TODO: allow air for other gases such as "air co2" for concentrations
    if (selections.size == 2)
    {
      // check if we have air as one choice
      airIndex := selections.findIndex { it.qname == "ph::Air" }
      if (airIndex != null)
      {
        // if one of the other choices is a gas then allow it
        otherIndex := airIndex == 0 ? 1 : 0
        other := selections[otherIndex]
        for (CSpec? x := other; x != null; x = x.cbase)
          if (x.qname == "ph::Gas") return
      }
    }

    onErr("Conflicting choice '$spec.ctype': " + selections.join(", ") { it.name })
  }

  ** Return if instance has all the given marker tags of the given choice
  static Bool hasChoiceMarkers(Dict instance, CSpec choice)
  {
    if (!choice.hasSlots) return false // skip abstract choice
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

