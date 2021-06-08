//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Nov 2015  Brian Frank  Creation
//

using haystack

**
** Folio utilities
**
@NoDoc
const class FolioUtil
{

//////////////////////////////////////////////////////////////////////////
// Constants
//////////////////////////////////////////////////////////////////////////

  static const Int maxRecIdSize := 60       // max chars in record id
  static const Int maxTagSize   := 60       // max chars in tag name
  static const Int maxUriSize   := 1000     // max chars in URI tag value
  static const Int maxStrSize   := 32767    // max chars in string tag value

//////////////////////////////////////////////////////////////////////////
// Validation
//////////////////////////////////////////////////////////////////////////

  ** Throw InvalidRecIdErr if not a valid record id
  **   - keep size to 60 to fit compound ids to be 128 bytes
  **   - prevent people from reusing Niagara ids such as "S.site.equip.point"
  **   - reserve colon for future compound refs
  static Void checkRecId(Ref id)
  {
    s := id.id
    if (s.getSafe(1) == '.' && s[0].isUpper) throw InvalidRecIdErr("Cannot use Niagara id: $s")
    if (s.size > maxRecIdSize) throw InvalidRecIdErr("Id too long: $s")
    if (s.contains(":")) throw InvalidRecIdErr("Id cannot contain colon: $s")
  }

  ** Throw InvalidTagNameErr if not a valid folio tag name
  static Void checkTagName(Str name)
  {
    if (!Etc.isTagName(name)) throw InvalidTagNameErr("Invalid tag name chars: $name")
    if (name.size > maxTagSize) throw InvalidTagNameErr("Tag too long: $name")
  }

  ** Throw InvalidTagValErr if not a valid folio tag value
  static Kind checkTagVal(Str name, Obj? val)
  {
    // check null
    if (val == null) throw InvalidTagValErr("Tag cannot be null: $name")

    // check kind
    kind := Kind.fromVal(val, false) ?: throw InvalidTagValErr("Unsupported tag type: $val.typeof")

    // Str/Uri limits
    if (kind === Kind.str && val.toStr.size > maxStrSize) throw InvalidTagValErr("Tag '$name' has Str value > $maxStrSize chars")
    if (kind === Kind.uri && val.toStr.size > maxUriSize) throw InvalidTagValErr("Tag '$name' Uri value > $maxUriSize chars")

    // 'name' tag value
    if (name == "name")
    {
      if (val is Str)
      {
        if (!Etc.isTagName(val)) throw InvalidTagValErr("Invalid 'name' tag value ${val->toCode}")
      }
      else if (val isnot Remove)
      {
        throw InvalidTagValErr("Tag 'name' must be a Str")
      }
    }

    return kind
  }

  ** Throw an exception such as InvalidTagValErr if the diff doesn't declare valid tags
  static Void checkDiff(Diff diff)
  {
    // check that add/remove aren't transient
    if (diff.isTransient)
    {
      if (diff.isAdd) throw DiffErr("Invalid diff flags: transient + add")
      if (diff.isRemove) throw DiffErr("Invalid diff flags: transient + remove")
    }

    // check for valid add id
    if (diff.isAdd) checkRecId(diff.id)

    // check tag name and values to insert
    diff.changes.each |Obj? val, Str name|
    {
      checkTagName(name)
      kind := checkTagVal(name, val)
      DiffTagRule.check(diff, name, kind, val)
    }
  }

  ** Check a list of diffs
  static Void checkDiffs(Diff[] diffs)
  {
    if (diffs.size == 0) throw DiffErr("No diffs to commit")
    if (diffs.size == 1) return checkDiff(diffs.first)

    dups := Ref:Diff[:]
    transient := diffs.first.isTransient
    diffs.each |diff|
    {
      checkDiff(diff)
      if (diff.isTransient != transient) throw DiffErr("Cannot mix transient and persistent diffs")
      if (dups[diff.id] != null) throw DiffErr("Duplicate diffs for $diff.id")
      dups[diff.id] = diff
    }
  }

  ** Strip any tags which cannot be persistently committed to Folio.
  ** This includes special tags such as 'hisSize' and any transient
  ** tags the record has defined.
  static Dict stripUncommittable(Folio folio, Dict d, Dict? opts := null)
  {
    if (opts == null) opts = Etc.emptyDict

    transients := Etc.emptyDict
    if (d.has("id"))
      transients = folio.readByIdTransientTags(d.id, false) ?: Etc.emptyDict

    acc := Str:Obj[:]
    d.each |v, n|
    {
      if (v == null) return
      if (transients.has(n)) return
      if (DiffTagRule.isUncommittable(n)) return
      if (n == "id" && opts["id"] == Remove.val) return
      acc[n] = v
    }
    return Etc.makeDict(acc)
  }
}

**************************************************************************
** DiffTagRule
**************************************************************************

@NoDoc @Js enum class DiffTagRule
{
  never,
  restricted,
  persistentOnly,
  transientOnly

  static Void check(Diff diff, Str name, Kind kind, Obj val)
  {
    // value rules
    if (kind == Kind.bin && diff.isTransient) throw DiffErr("Bin tag cannot be transient")

    // tag name rules
    rule := rules[name]
    if (rule == null) return
    switch (rule)
    {
      case never:
        throw DiffErr("Cannot set tag: $name.toCode")
      case restricted:
        checkRestricted(diff, name, kind, val)
      case transientOnly:
        if (!diff.isTransient) throw DiffErr("Cannot set tag persistently: $name.toCode")
      case persistentOnly:
        if (diff.isTransient) throw DiffErr("Cannot set tag transiently: $name.toCode")
    }
  }

  static Bool isUncommittable(Str name)
  {
    rule := rules[name]
    if (rule == null) return false
    if (rule == transientOnly) return true
    if (rule == never)
    {
      if (name == "id") return false
      return true
    }
    return false
  }

  private static Void checkRestricted(Diff diff, Str name, Kind kind, Obj val)
  {
    if (diff.isBypassRestricted) return

    if (diff.isAdd) throw DiffErr("Cannot add rec with restricted tag: $name.toCode")
    if (val == Remove.val) throw DiffErr("Cannot remove restricted tag: $name.toCode")
    throw DiffErr("Cannot set restricted tag: $name.toCode")
  }

  static const Str:DiffTagRule rules :=
  [
    "id":          never,
    "mod":         never,
    "transient":   never,

    "projMeta":    restricted,
    "uiMeta":      restricted,
    "ext":         restricted,
    "hxLib":       restricted,

    "conn":        persistentOnly,
    "dis":         persistentOnly,
    "disMacro":    persistentOnly,
    "equip":       persistentOnly,
    "navName":     persistentOnly,
    "point":       persistentOnly,
    "site":        persistentOnly,
    "trash":       persistentOnly,

    "connState":   transientOnly,
    "connStatus":  transientOnly,
    "connErr":     transientOnly,

    "curVal":      transientOnly,
    "curStatus":   transientOnly,
    "curErr":      transientOnly,

    "writeVal":    transientOnly,
    "writeLevel":  transientOnly,
    "writeStatus": transientOnly,
    "writeErr":    transientOnly,

    "nextTime":    transientOnly,
    "nextVal":     transientOnly,

    "hisStatus":   transientOnly,
    "hisErr":      transientOnly,

    "hisId":       never,
    "hisSize":     never,
    "hisStart":    never,
    "hisStartVal": never,
    "hisEnd":      never,
    "hisEndVal":   never,
  ]
}