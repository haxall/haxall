//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Sep 2026  Brian Frank  Creation
//

using util
using xeto
using haystack

// One class per ph ValidateRule instance, named "Validate" plus the rule
// name the same way every lib binds its rules - see ValidateRule.create.
// So keep this file in sync with ph validation.xeto.

**************************************************************************
** Point
**************************************************************************

@Js internal const class ValidatePointMissingSiteRef : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    dict := s.dict
    if (dict == null) return
    if (dict.missing("siteRef") && dict.missing("weatherStationRef")) s.emit
  }
}

@Js internal const class ValidatePointMissingTz : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    if (s.dict?.missing("tz") ?: false) s.emit
  }
}

@Js internal const class ValidatePointSiteTz : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    tz := s.dict?.get("tz")
    if (tz == null) return // pointMissingTz's check

    // a point may belong to a site or a weather station
    parent := s.readRef("siteRef") ?: s.readRef("weatherStationRef")
    if (parent == null) return

    parentTz := parent["tz"]
    if (parentTz != null && !Etc.eq(tz, parentTz))
      s.emitOn("tz", Etc.dict1("siteTz", parentTz))
  }
}

**************************************************************************
** Site Containment
**************************************************************************

** A rec which references a container must agree with it about the site.
** The ref target types are checked by refTargetType; this checks that
** the two paths to a site lead to the same one.
@Js internal abstract const class ValidateRefSite : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}

  ** Ref tag naming the container to cross check
  abstract Str refTag()

  override Void onCheck(ValidateState s)
  {
    site := s.dict?.get("siteRef")
    if (site == null) return

    // the tag may be a Ref or a MultiRef list; every target must agree
    s.readRefs(refTag).each |parent|
    {
      parentSite := parent["siteRef"]
      if (parentSite != null && !Etc.eq(site, parentSite))
        s.emitOn("siteRef", Etc.dict1("refSite", parentSite))
    }
  }
}

@Js internal const class ValidateEquipRefSite : ValidateRefSite
{
  new make(ValidateRuleInit init) : super(init) {}
  override Str refTag() { "equipRef" }
}

@Js internal const class ValidateSpaceRefSite : ValidateRefSite
{
  new make(ValidateRuleInit init) : super(init) {}
  override Str refTag() { "spaceRef" }
}

@Js internal const class ValidateSystemRefSite : ValidateRefSite
{
  new make(ValidateRuleInit init) : super(init) {}
  override Str refTag() { "systemRef" }
}
