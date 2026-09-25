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
** Point Values
**************************************************************************

@Js internal const class ValidatePointValUnit : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    // haystack fidelity encodes unit as Str, xeto fidelity as Unit
    unit := ValidateWrongEnumKey.enumKey(s.dict?.get("unit"))
    if (unit == null) return
    ["minVal", "maxVal"].each |tag|
    {
      // unitless is implicitly in the point's unit
      num := s.dict.get(tag) as Number
      if (num?.unit != null && num.unit.symbol != unit) s.emitOn(tag, Etc.dict1("unit", unit))
    }
  }
}

@Js internal const class ValidatePointMinMax : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    min := s.dict?.get("minVal") as Number
    max := s.dict?.get("maxVal") as Number
    if (min == null || max == null) return
    if (min.unit != null && max.unit != null && min.unit != max.unit) return // pointValUnit's check
    if (min > max) s.emitOn("minVal", Etc.dict1("maxVal", max))
  }
}

**************************************************************************
** Containment
**************************************************************************

** The equipRef, spaceRef, and systemRef tags form a tree rooted at a
** site.  These two rules walk that tree: refSite checks every ancestor
** agrees about the site, refCycle catches a cycle which would make the
** parent/child queries recurse forever.
@Js internal abstract const class ValidateContainment : ValidateRule
{
  new make(ValidateRuleInit init) : super(init) {}

  ** Tags which form the containment tree
  static const Str[] refTags := ["equipRef", "spaceRef", "systemRef"]

  ** Max ancestors walked before giving up, so a cycle through tags we do
  ** not follow cannot hang the validation
  private static const Int maxDepth := 100

  ** Walk the chain of ancestors reachable from a tag and call f with each
  ** one.  A MultiRef tag starts a chain per ref.  When a chain revisits an
  ** id, f is passed null plus the ids walked, and that chain stops.
  protected Void eachAncestor(ValidateState s, Str tag, |Dict?, Ref[]| f)
  {
    start := s.dict?.get("id") as Ref
    s.readRefs(tag).each |rec|
    {
      seen := start == null ? Ref[,] : Ref[start]
      Dict? cur := rec
      while (cur != null && seen.size < maxDepth)
      {
        id := cur["id"] as Ref
        if (id != null && seen.contains(id)) { f(null, seen.dup.add(id)); break }
        if (id != null) seen.add(id)
        f(cur, seen)

        next := cur[tag] as Ref
        cur = next == null ? null : s.readById(next)
      }
    }
  }
}

@Js internal const class ValidateRefSite : ValidateContainment
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    site := s.dict?.get("siteRef")
    if (site == null) return

    refTags.each |tag|
    {
      eachAncestor(s, tag) |rec, path|
      {
        if (rec == null) return // refCycle's check
        recSite := rec["siteRef"]
        if (recSite != null && !Etc.eq(site, recSite))
          s.emitOn("siteRef", Etc.dictx("refTag", tag, "refSite", recSite))
      }
    }
  }
}

@Js internal const class ValidateRefCycle : ValidateContainment
{
  new make(ValidateRuleInit init) : super(init) {}
  override Void onCheck(ValidateState s)
  {
    refTags.each |tag|
    {
      eachAncestor(s, tag) |rec, path|
      {
        if (rec == null)
          s.emitOn(tag, Etc.dictx("refTag", tag, "path", path.join(" -> ")))
      }
    }
  }
}
