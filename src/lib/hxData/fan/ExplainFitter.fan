//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jan 2023  Brian Frank  Creation
//

using data
using haystack
using hx

**
** ExplainFitter
**
class ExplainFitter : Fitter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(HxContext cx) : super(cx) {}

//////////////////////////////////////////////////////////////////////////
// Top
//////////////////////////////////////////////////////////////////////////

  Grid explain(Obj? val, DataSpec type)
  {
    failFast = false
    recs := Etc.toRecs(val)
    recs.each |rec|
    {
      startRow := rows.size

      subject = rec
      subjectId = rec["id"] as Ref
      fits(rec, type)

      // insert summary about the rows we added for this rec
      numAdded := rows.size - startRow
      if (numAdded > 0)
      {
        countStr := numAdded == 1 ? "1 error" : "$numAdded errors"
        rows.insert(startRow, [subjectId, countStr])
      }
    }
    return toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Fitter Overrides
//////////////////////////////////////////////////////////////////////////

  override Bool explainNoType(Obj? val)
  {
    log("Value not mapped to data type [${val?.typeof}]")
  }

  override Bool explainNoFit(DataSpec valType, DataSpec type)
  {
    log("Type '$valType' does not fit '$type'")
  }

  override Bool explainMissingSlot(DataSpec slot)
  {
    if (slot.type.isMarker)
      return log("Missing required marker '$slot.name'")
    else
      return log("Missing required slot '$slot.name'")
  }

  override Bool explainMissingQueryConstraint(Str ofDis, DataSpec constraint)
  {
    log("Missing required $ofDis $constraint.name")
  }

  override Bool explainAmbiguousQueryConstraint(Str ofDis, DataSpec constraint, Dict[] matches)
  {
    log("Ambiguous match for $ofDis $constraint.name: " + recsToDis(matches))
  }

  override Bool explainInvalidSlotType(Obj val, DataSpec slot)
  {
    log("Invalid value type for '$slot.name' - '${val.typeof}' does not fit '$slot.type'")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Str recsToDis(Dict[] recs)
  {
    s := StrBuf()
    for (i := 0; i<recs.size; ++i)
    {
      rec := recs[i]
      str := "@" + rec->id
      dis := relDis(rec)
      if (dis != null) str += " $dis.toCode"
      s.join(str, ", ")
      if (s.size > 50 && i+1<recs.size)
        return s.add(", ${recs.size - i - 1} more ...").toStr
    }
    return s.toStr
  }

  private Str? relDis(Dict d)
  {
    x := dis(d)
    if (x == null) return null

    p := dis(subject)
    if (p == null) return x

    return Etc.relDis(p, x)
  }

  private Str? dis(Dict? d)
  {
    d?.get("dis", null)
  }

  private Bool log(Str msg)
  {
    rows.add([subjectId, msg])
    return false
  }

  private Grid toGrid()
  {
    gb := GridBuilder()
    gb.addCol("lintRef")
    gb.addCol("msg")
    gb.capacity = rows.size
    rows.each |row| { gb.addRow(row) }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private Dict? subject
  private Ref? subjectId
  private Obj?[][] rows := [,]
}