//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Jul 2025  Matthew Giannini  Creation
//

using xeto

**
** Fold manages a running accumulation
**
@NoDoc
@Js
abstract class Fold
{

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  ** Find a fold by its name and instantiate it by passing the meta as the first
  ** parameter to the fold's 'make' method. If the fold isn't found and checked is
  ** true then throw an `UnknownNameErr`; otherwise return null.
  static Fold? instantiate(Str name, Dict meta := Etc.emptyDict, Bool checked := true)
  {
    t := byName[name]
    if (t != null) return t.method("make").call(meta)
    if (checked) throw UnknownNameErr("Folding func: ${name}")
    return null
  }
  private static const Str:Type byName

  static
  {
    accByName := Str:Type[:]

    // utility for mapping fold name to type and putting in accByName
    add := |Str p, Str n->Type?|
    {
      typeName := "Fold${n.capitalize}"
      t := Pod.find(p, false)?.type(typeName, false)
      if (t == null) echo("ERR: haystack.fold ${typeName} not found in ${p}")
      else if (accByName.containsKey(n)) echo("ERR: haystack.fold duplicate definitions for ${n}: ${accByName.get(n)} and ${p}::${typeName}")
      else accByName[n] = t
      return t
    }

    // these are explicitly allowed in all environments
    ["list", "sum", "min", "max", "avg"].each |n| { add("haystack", n) }
    accByName.setNotNull("delta", accByName["avg"])

    // only use index when not in the browser
    if (!Env.cur.isBrowser)
    {
      Env.cur.indexByPodName("haystack.fold").each |Str[] folds, pod|
      {
        folds.each |name| { add(pod, name) }
      }
    }

    byName = accByName
  }

  ** Lookup the name of the default folding function for the given tag/column name
  static Str findDef(Str name)
  {
    if (name == "periods") return "periodUnion"
    return "sum"
  }

//////////////////////////////////////////////////////////////////////////
// Fold
//////////////////////////////////////////////////////////////////////////

  ** The name of this fold
  once Str name() { typeof.name["Fold".size..-1].decapitalize }

  ** Fold the accumulation into its final value
  abstract Obj? finish()

  ** Accumulate another value
  abstract Void add(Obj val)

  ** Batch the accumalation into an object for serialization
  abstract Obj? batch()

  ** Add an encoded batch to the running accumalation
  abstract Void addBatch(Obj batch)

}

**************************************************************************
** FoldCount
**************************************************************************

@Js
internal class FoldCount : Fold
{
  override Obj? finish() { Number(count) }
  override Void add(Obj val) { count++ }
  override Obj? batch() { finish }
  override Void addBatch(Obj v) { count += ((Number)v).toInt }
  private Int count
}

**************************************************************************
** FoldList
**************************************************************************

@Js
internal class FoldList : Fold
{
  override Obj? finish()
  {
    items := this.items.vals.sortr |a, b| { a.count <=> b.count }
    if (items.size > max) items = items[0..max]
    return items.map |item| { [item.key, Number(item.count)] }
  }

  override Void add(Obj val)
  {
    item := items[val]
    if (item == null) items[val] = item = FoldCountItem(val)
    item.count++
  }

  override Obj? batch() { finish }

  override Void addBatch(Obj v)
  {
    ((List)v).each |List b|
    {
      val := b[0]
      count := ((Number)b[1]).toInt
      item := items[val]
      if (item == null) items[val] = item = FoldCountItem(val)
      item.count += count
    }
  }

  static const Int max := 20

  private Obj:FoldCountItem items := [:]
}

@Js
internal class FoldCountItem
{
  new make(Obj key) { this.key = key }
  const Obj key
  Int count
}

**************************************************************************
** FoldNum
**************************************************************************

@Js
internal abstract class FoldNum : Fold
{
  override Obj? finish()
  {
    if (mode === FoldNumMode.first) return null
    if (mode === FoldNumMode.na) return NA.val
    return Number.make(finishNum, unit)
  }

  override Void add(Obj val)
  {
    // check NA
    if (mode === FoldNumMode.na) return
    if (val === NA.val) { mode = FoldNumMode.na; return }

    // skip anything else not a Number
    n := val as Number
    if (n == null) return

    // check unit
    addUnit(n.unit)

    // accumulate the floating point value
    addNum(n.toFloat)
    mode = FoldNumMode.ok
  }

  override Obj? batch() { finish }

  override Void addBatch(Obj v) { add(v) }

  abstract Float finishNum()

  abstract Void addNum(Float n)

  Void addUnit(Unit? u)
  {
    if (mode === FoldNumMode.first)
    {
      unit = u
    }
    else if (unit != u)
    {
      unit = null
    }
  }

  internal FoldNumMode mode := FoldNumMode.first
  internal Unit? unit
}

@Js internal enum class FoldNumMode { first, na, ok }

**************************************************************************
** FoldSum
**************************************************************************

@Js
internal class FoldSum : FoldNum
{
  override Float finishNum() { sum }
  override Void addNum(Float f) { sum += f }
  private Float sum
}

**************************************************************************
** FoldMin
**************************************************************************

@Js
internal class FoldMin : FoldNum
{
  override Float finishNum() { min  }
  override Void addNum(Float f) { min = min.min(f) }
  private Float min := Float.posInf
}

**************************************************************************
** FoldMax
**************************************************************************

@Js
internal class FoldMax : FoldNum
{
  override Float finishNum() { max  }
  override Void addNum(Float f) { max = max.max(f) }
  private Float max := Float.negInf
}

**************************************************************************
** FoldAvg
**************************************************************************

@Js
internal class FoldAvg : FoldNum
{
  override Float finishNum() { sum / count.toFloat }

  override Void addNum(Float f) { sum += f; count++ }

  override Obj? batch()
  {
    if (mode != FoldNumMode.ok) return super.batch
    return [Number(sum), Number(count), unit?.symbol]
  }

  override Void addBatch(Obj v)
  {
    if (mode == FoldNumMode.na || v isnot List) return super.addBatch(v)
    list := (Obj?[])v
    sum += ((Number)list[0]).toFloat
    count += ((Number)list[1]).toInt
    addUnit(Unit.fromStr(list[2] ?: "_null_", false))
    mode = FoldNumMode.ok
  }

  private Float sum
  private Int count
}
