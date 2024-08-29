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

  // earliest year supported by historian is 1950
  static const Int hisMinYear    := 1950
  static const Date hisMinDate   := Date(hisMinYear, Month.jan, 1)
  static const DateTime hisMinTs := hisMinDate.midnight(TimeZone.utc)

//////////////////////////////////////////////////////////////////////////
// Diffs
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
        // allow name tag be dotted lib names too
        if (!Etc.isTagName(val) && !Etc.isTagName(val.toStr.replace(".", "_"))) throw InvalidTagValErr("Invalid 'name' tag value ${val->toCode}")
      }
      else if (val isnot Remove)
      {
        throw InvalidTagValErr("Tag 'name' must be a Str")
      }
    }

    return kind
  }

  ** Check a list of diffs
  static Void checkDiffs(Diff[] diffs)
  {
    if (diffs.size == 0) throw DiffErr("No diffs to commit")
    if (diffs.size == 1) return

    dups := Ref:Diff[:]
    transient := diffs.first.isTransient
    diffs.each |diff|
    {
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
      if (transients.has(n)) return
      if (n == "mod" && opts.has("mod")) { acc[n] = v; return }
      if (DiffTagRule.isUncommittable(n)) return
      if (n == "id" && opts["id"] === Remove.val) return
      acc[n] = v
    }
    return Etc.makeDict(acc)
  }

  ** Return if the given tag name should never be persistently committed to Folio
  static Bool isUncommittable(Str name)
  {
    DiffTagRule.isUncommittable(name)
  }

  ** Compute a map of tag names which should never be index
  static Str:Str tagsToNeverIndex()
  {
    acc := Str:Str[:]
    acc.addList(["id", "mod", "trash"])
    DiffTagRule.rules.each |r, n|
    {
      if (r.type === DiffTagRuleType.transientOnly ||
          r.type === DiffTagRuleType.never)
        acc[n] = n
    }
    return acc
  }

  ** Tags we never want to include in Haystack learn
  static Str:Str tagsToNeverLearn()
  {
    acc := Str:Str[:]
    acc.addList([
      "navId", "disMacro", "navName",
      "cur", "his", "writable",
      "hisCollectInterval", "hisCollectCov"
    ])
    DiffTagRule.rules.each |r, n|
    {
      if (r.type === DiffTagRuleType.transientOnly ||
          r.type === DiffTagRuleType.never)
        acc[n] = n
    }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// History Point Config
//////////////////////////////////////////////////////////////////////////

  ** Configured tz tag or raise HisConfigErr
  static TimeZone? hisTz(Dict rec, Bool checked := true)
  {
    val := rec["tz"]
    if (val == null)
    {
      if (checked) throw HisConfigErr(rec, "Missing 'tz' tag")
      return null
    }

    str := val as Str
    if (str == null)
    {
      if (checked) throw HisConfigErr(rec, "Invalid type for 'tz' tag: $val.typeof")
      return null
    }

    tz := TimeZone.fromStr(str, false)
    if (tz == null)
    {
      if (checked) throw HisConfigErr(rec, "Invalid 'tz' tag: $str")
      return null
    }

    return tz
  }

  ** Configured kind or raise HisConfigErr
  static Kind? hisKind(Dict rec, Bool checked := true)
  {
    val := rec["kind"]
    if (val == null)
    {
      if (checked) throw HisConfigErr(rec, "Missing 'kind' tag")
      return null
    }

    str := val as Str
    if (str == null)
    {
      if (checked) throw HisConfigErr(rec, "Invalid type for 'kind' tag: $val.typeof")
      return null
    }

    kind := Kind.fromStr(str, false)
    if (kind == null)
    {
      if (checked) throw HisConfigErr(rec, "Invalid 'kind' tag: $str")
      return null
    }

    if (!isHisKind(kind))
    {
      if (checked) throw HisConfigErr(rec, "Unsupported 'kind' for his: $kind")
      return null
    }

    return kind
  }

  ** Configured unit tag or raise HisConfigErr
  static Unit? hisUnit(Dict rec, Bool checked := true)
  {
    val := rec["unit"]
    if (val == null) return null

    str := val as Str
    if (str == null)
    {
      if (checked) throw HisConfigErr(rec, "Invalid type for 'unit' tag: $val.typeof")
      return null
    }

    unit := Number.loadUnit(str, false)
    if (unit == null)
    {
      if (checked) throw HisConfigErr(rec, "Invalid 'unit' tag: $str")
      return null
    }

    return unit
  }


  ** Return 1sec or 1ms for timestamp precision or raise HisConfigErr
  static Duration? hisTsPrecision(Dict rec, Bool checked := true)
  {
    // get tag
    val := rec["hisTsPrecision"]
    if (val == null) return 1sec

    // check that tag is number
    num := val as Number
    if (num == null)
    {
      if (checked) throw HisConfigErr(rec, "Invalid type for hisTsPrecision: $val.typeof.name")
      return null
    }

    // check for 1sec or 1ms
    dur := num.toDuration(false)
    if (dur == 1ms) return 1ms
    if (dur == 1sec) return 1sec

    if (checked) throw HisConfigErr(rec, "Unsupported hisTsPrecision: $num")
    return null
  }

  ** Is given kind supported for history items
  static Bool isHisKind(Kind kind)
  {
    kind === Kind.number ||
    kind === Kind.bool   ||
    kind === Kind.str    ||
    kind === Kind.coord
  }

//////////////////////////////////////////////////////////////////////////
// His Write
//////////////////////////////////////////////////////////////////////////

  ** Verify point rec and his items, return safe copy of normalized, sorted items.
  ** Duplicate normalized timestamps are removed - for pre-sorted items then the
  ** one latest in the list is used, for unsorted items then its indetermine
  ** which one is kept.
  static HisItem[] hisWriteCheck(Dict rec, HisItem[] items, Dict opts := Etc.emptyDict)
  {
    // options
    forecast := opts.has("forecast")
    clip := opts["clip"] as Span
    unitSet := opts.has("unitSet")

    // point checks
    if (rec["point"] !== Marker.val) throw HisConfigErr(rec, "Rec missing 'point' tag")
    if (rec["his"] !== Marker.val) throw HisConfigErr(rec, "Rec missing 'his' tag")
    if (rec.has("aux")) throw HisConfigErr(rec, "Rec marked as 'aux'")
    if (rec.has("trash")) throw HisConfigErr(rec, "Rec marked as 'trash'")

    // configuration
    kind        := hisKind(rec)
    tz          := hisTz(rec)
    unit        := hisUnit(rec)
    tsPrecision := hisTsPrecision(rec)
    isNumber    := kind === Kind.number

    // first check if data is sorted (95% of the time is should be)
    sorted := true
    for (i:=1; i<items.size; ++i)
      if (items[i-1].ts > items[i].ts) sorted = false
    if (!sorted) items = items.dup.sort

    // make normalized copy
    acc := HisItem[,]
    acc.capacity = items.size
    for (i:=0; i<items.size; ++i)
    {
      item := items[i]

      // check timezone
      if (item.ts.tz !== tz)
        throw HisWriteErr(rec, "Mismatched timezone, rec tz $tz.name.toCode != item tz $item.ts.tz.name.toCode")
      if (item.ts.year < hisMinYear)
        throw HisWriteErr(rec, "Timestamps before $hisMinYear not supported: $item")

      // normalize timestamp
      ts := item.ts.floor(tsPrecision)

      // toss it out if outside of option clip span
      if (clip != null && !clip.contains(ts)) continue

      // check value
      val := item.val
      if (val == null)
        throw HisWriteErr(rec, "Cannot write null val")
      if (val.typeof !== kind.type && val !== NA.val && val !== Remove.val)
        throw HisWriteErr(rec, "Mismatched value type, rec kind $kind.name.toCode != item type $val.typeof.qname.toCode")

      // extra handling for Number values
      if (isNumber && val is Number)
      {
        // check unit
        num := (Number)val
        if (num.unit == null)
        {
          if (unitSet && unit != null)
            val = num = Number(num.toFloat, unit)
        }
        else
        {
          if (num.unit != unit)
            throw HisWriteErr(rec, "Mismatched unit, rec unit '${unit}' != item unit '${num.unit}'")
        }

        // normalize non-integer values, and ensure we normalize -0.0
        if (!num.isInt)
        {
          f1 := num.toFloat
          f2 := Float.makeBits32(f1.bits32)
          if (f1 != f2) val = Number(f2, num.unit)
        }
        else if (num.toFloat.isNegZero)
        {
          val = Number(num.toFloat.normNegZero, num.unit)
        }

        // if forecast ensure we have unit
        if (forecast && num.unit != unit)
          val = Number(num.toFloat, unit)
      }

      // replace if same as previous timestamp otherwise append
      newItem := HisItem(ts, val)
      if (!acc.isEmpty && acc.last.ts == ts)
        acc[-1] = newItem
      else
        acc.add(newItem)
    }

    return acc
  }

  ** Apply a set of changes to history items and return the new updated
  ** items to persist.  Both lists must already be normalized and
  ** sorted (all changes should already be verified by 'hisWriteCheck').
  ** Changes are applied as follows:
  **   - new items are interleaved into temporal order
  **   - if dup ts, then changes overwrites cur
  **   - if changes is Remove.val it removed from cur
  static HisItem[] hisWriteMerge(HisItem[] cur, HisItem[] changes)
  {
    // handle special cases
    if (changes.isEmpty) return cur.dup
    if (cur.isEmpty) return changes.findAll |item| { item.val !== Remove.val }

    acc := HisItem[,]
    ax := cur;     a := cur.first;     ai := 0
    bx := changes; b := changes.first; bi := 0
    while (true)
    {
      if (a.ts < b.ts)
      {
        acc.add(a)
        ai++
        if (ai >= ax.size) break
        a = ax[ai]
      }
      else if (a.ts > b.ts)
      {
        if (b.val !== Remove.val) acc.add(b)
        bi++
        if (bi >= bx.size) break
        b = bx[bi]
      }
      else // same ts
      {
        if (b.val !== Remove.val) acc.add(b)
        ai++
        bi++
        if (ai >= ax.size) break
        a = ax[ai]
        if (bi >= bx.size) break
        b = bx[bi]
      }
    }
    while (ai < ax.size) { a = ax[ai++]; acc.add(a) }
    while (bi < bx.size) { b = bx[bi++]; if (b.val !== Remove.val) acc.add(b) }
    return acc
  }
}

**************************************************************************
** DiffTagRule
**************************************************************************

**
** DiffTagRule provides hardcoded checks for specific tags
**
internal const class DiffTagRule
{
  new make(DiffTagRuleType type, Int diffFlags)
  {
    this.type = type
    this.diffFlags = diffFlags
  }

  ** Type: never, restricted, persistentOnly, transientOnly
  const DiffTagRuleType type

  ** Flags to mix into
  const Int diffFlags

  ** Check one name/value pair of a Diff's changes.
  ** Return Diff bitmask flags to mix into final flags
  static Int check(Diff diff, Str name, Kind kind, Obj val)
  {
    // value rules
    if (kind === Kind.bin && diff.isTransient) throw DiffErr("Bin tag cannot be transient")

    // tag name rules
    rule := rules[name]
    if (rule == null) return 0
    switch (rule.type)
    {
      case DiffTagRuleType.never:
        throw DiffErr("Cannot set tag: $name.toCode")
      case DiffTagRuleType.restricted:
        checkRestricted(diff, name, kind, val)
      case DiffTagRuleType.transientOnly:
        if (!diff.isTransient) throw DiffErr("Cannot set tag persistently: $name.toCode")
      case DiffTagRuleType.persistentOnly:
        if (diff.isTransient) throw DiffErr("Cannot set tag transiently: $name.toCode")
    }

    return rule.diffFlags
  }

  static Bool isUncommittable(Str name)
  {
    rule := rules[name]
    if (rule == null) return false
    if (rule.type === DiffTagRuleType.transientOnly) return true
    if (rule.type === DiffTagRuleType.never)
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
    if (val === Remove.val) throw DiffErr("Cannot remove restricted tag: $name.toCode")
    throw DiffErr("Cannot set restricted tag: $name.toCode")
  }

  static const Str:DiffTagRule rules
  static
  {
    never          := DiffTagRule(DiffTagRuleType.never, 0)
    restricted     := DiffTagRule(DiffTagRuleType.restricted, 0)
    persistentOnly := DiffTagRule(DiffTagRuleType.persistentOnly, 0)
    transientOnly  := DiffTagRule(DiffTagRuleType.transientOnly, 0)
    curVal         := DiffTagRule(DiffTagRuleType.transientOnly, Diff.curVal)
    point          := DiffTagRule(DiffTagRuleType.persistentOnly, Diff.point)

    rules = [
      "id":          never,
      "mod":         never,
      "transient":   never,

      "projMeta":    restricted,
      "uiMeta":      restricted,
      "ext":         restricted,

      "conn":        persistentOnly,
      "dis":         persistentOnly,
      "disMacro":    persistentOnly,
      "equip":       persistentOnly,
      "navName":     persistentOnly,
      "point":       point,
      "site":        persistentOnly,
      "trash":       persistentOnly,

      "connState":   transientOnly,
      "connStatus":  transientOnly,
      "connErr":     transientOnly,

      "curVal":      curVal,
      "curStatus":   curVal,
      "curErr":      transientOnly,
      "curSource":   transientOnly,

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

      "userFailedLogins": transientOnly,
    ]
  }
}

internal enum class DiffTagRuleType
{
  never,
  restricted,
  persistentOnly,
  transientOnly
}