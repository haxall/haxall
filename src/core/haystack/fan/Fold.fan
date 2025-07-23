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

  ** Lookup a fold by name and create an instance with the given meta.
  ** The implementation of the fold will adhere to Axon semantics. If the
  ** fold is not found, throw an `UnknownNameErr` if checked; otherwise return null.
  static Fold? createAxon(Str name, Dict meta := Etc.dict0, Bool checked := true)
  {
    createFold(name, true, meta, checked)
  }

  ** Lookup a fold by name and create an instance with the given meta.
  ** The implementation of the fold will adhere to Pivot table semantics. If the
  ** fold is not found, throw an `UnknownNameErr` if checked; otherwise return null.
  static Fold? createPivot(Str name, Dict meta := Etc.dict0, Bool checked := true)
  {
    createFold(name, false, meta, checked)
  }

  ** Common implementation for creating a fold
  private static Fold? createFold(Str name, Bool axon, Dict meta, Bool checked)
  {
    t := byName[name]
    if (t != null) return t.make([axon, meta])
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
    ["count", "list", "sum", "min", "max", "avg", "spread"].each |n| { add("haystack", n) }
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

  new make(Bool axon, Dict meta)
  {
    this.axon = axon
    this.meta = meta
  }

  ** If true, the fold should execute with Axon semantics. If false, it will
  ** execute with pivot table semantics.
  const Bool axon

  ** Configuration metadata for the fold.
  const Dict meta

  ** Convenience for '!axon'
  Bool pivot() { !axon }

  ** The name of this fold
  once Str name() { meta.get("name") ?: typeof.name["Fold".size..-1].decapitalize }

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
  new make(Bool axon, Dict meta) : super(axon, meta) { }
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
  new make(Bool axon, Dict meta) : super(axon, meta) { }

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
  new make(Bool axon, Dict meta) : super(axon, meta) { }

  override Obj? finish()
  {
    if (mode === FoldNumMode.first) return null
    if (mode === FoldNumMode.na) return NA.val
    num := finishNum
    return num.isNaN ? Number.nan : Number.make(num, unit)
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
    if (pivot || !n.isNaN) addUnit(n.unit)

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
    if (unit == undefined_unit)
    {
      unit = u
    }
    else if (unit != u)
    {
      if (axon) throw UnitErr("${unit} + ${u}")
      unit = null
    }
  }

  private static const Unit undefined_unit := Unit.define("_fold_undef_")
  internal FoldNumMode mode := FoldNumMode.first
  internal Unit? unit := undefined_unit
}

@NoDoc @Js enum class FoldNumMode { first, na, ok }

**************************************************************************
** FoldSum
**************************************************************************

@Js
internal class FoldSum : FoldNum
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  override Float finishNum() { sum }
  override Void addNum(Float f) { sum += f }
  private Float sum
}

**************************************************************************
** FoldAvg
**************************************************************************

@Js
internal class FoldAvg : FoldNum
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }

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

**************************************************************************
** FoldExtreme
**************************************************************************

@Js
internal abstract class FoldExtreme : Fold
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  override Obj? finish()
  {
    if (mode === FoldNumMode.first) return null
    if (mode === FoldNumMode.na) return NA.val
    return onFinish
  }
  abstract protected Number onFinish()
  override Void add(Obj val)
  {
    // check NA
    if (mode === FoldNumMode.na) return
    if (val === NA.val) { mode = FoldNumMode.na; return }

    // skip anything else not a Number
    n := val as Number
    if (n == null) return

    if (min == null && max == null) { min = n; max = n }
    else
    {
      tempMin := n.min(min)
      tempMax := n.max(max)
      if (pivot && tempMin.unit != min.unit)
      {
        // unit changed; strip units
        tempMin = Number.make(tempMin.toFloat)
        tempMax = Number.make(tempMax.toFloat)
      }
      min = tempMin
      max = tempMax
    }
    mode = FoldNumMode.ok
  }
  override Obj? batch() { [min, max] }
  override Void addBatch(Obj v)
  {
    state := (List)v
    add(state[0])
    add(state[1])
  }

  private FoldNumMode mode := FoldNumMode.first
  protected Number? min { private set }
  protected Number? max { private set }
}

**************************************************************************
** FoldMin
**************************************************************************

@Js
internal class FoldMin : FoldExtreme
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  override protected Number onFinish() { this.min }
}

**************************************************************************
** FoldMax
**************************************************************************

@Js
internal class FoldMax : FoldExtreme
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  override protected Number onFinish() { this.max }
}

**************************************************************************
** FoldSpread
**************************************************************************

@Js
internal class FoldSpread : FoldExtreme
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  override protected Number onFinish() { this.max - this.min }
}

