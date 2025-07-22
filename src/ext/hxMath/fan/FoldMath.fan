//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Feb 2012   Brian Frank   Creation
//

using xeto
using haystack
using util

**************************************************************************
** MathFold
**************************************************************************

internal abstract class FoldMath : Fold
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }

  Int size { private set }
  FloatArray array := FloatArray.makeF8(1024) { private set }
  Unit? unit { private set }
  FoldNumMode mode := FoldNumMode.first { private set }

  override Obj? finish()
  {
    switch (mode)
    {
      case FoldNumMode.first: return null
      case FoldNumMode.na: return NA.val
      default:
        val := onFinish
        return val == null ? null : Number(val, unit)
    }
  }

  protected abstract Float? onFinish()

  override Void add(Obj val)
  {
    // check NA
    if (mode === FoldNumMode.na) return
    if (val === NA.val) { mode = FoldNumMode.na; return }

    num := (Number)val
    if (unit == null) unit = num.unit
    if (size == array.size)
    {
      grow := FloatArray.makeF8(array.size*2)
      grow.copyFrom(array)
      this.array = grow
    }
    array[size++] = num.toFloat
    mode = FoldNumMode.ok
  }

  override Obj? batch()
  {
    if (mode === FoldNumMode.na) return NA.val
    return [array, size, unit]
  }

  override Void addBatch(Obj batch)
  {
    if (batch === NA.val) return add(batch)

    // TODO: very inefficient, could be more clever with grow and copy
    state := (List)batch
    arr := (FloatArray)state[0]
    size := (Int)state[1]
    unit := (Unit?)state[2]
    size.times |i| { add(Number(arr[i], unit)) }
  }

  ** Compute mean - useful for several of the math folds
  Float mean()
  {
    sum := 0f
    for (i:=0; i<size; ++i) sum += array[i]
    return sum/size.toFloat
  }

  ** Compute median - useful for several of the math folds
  protected Float median()
  {
    array.sort(0..<size)
    if (size.isOdd) return array[size/2]
    a := array[size/2-1]
    b := array[size/2]
    return (a+b)/2f
  }
}

**************************************************************************
** FoldMedian
**************************************************************************

internal class FoldMedian : FoldMath
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  protected override Float? onFinish() { this.median }
}

**************************************************************************
** FoldRootMeanSquare
**************************************************************************

internal class FoldRootMeanSquareErr : FoldMath
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  protected override Float? onFinish()
  {
    // this behavior came from PNL, but I'm not sure its
    // quite correct because it uses median as the "truth"
    // value which seems hokey

    // if sample size is smaller than degrees of freedom return null
    nDegrees := (meta.get("n") as Number)?.toInt ?: 0
    if (size <= nDegrees) return null

    // compute median
    median := this.median

    // compute Σ(xᵢ - median)²
    sumsq := 0f
    for (i:=0; i<size; ++i)
    {
      diff := array[i] - median
      sumsq += diff * diff
    }

    // put it together
    rmse := 1f / (size - nDegrees) * sumsq.sqrt
    return rmse
  }
}

**************************************************************************
** FoldMeanBiasErr
**************************************************************************

internal class FoldMeanBiasErr : FoldMath
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  protected override Float? onFinish()
  {
    // this function came from PNL, but I'm not sure its
    // quite correct because it uses median as the "truth"
    // value which seems hokey

    // if sample size smaller than degrees of freedom return null
    nDegrees := (meta.get("n") as Number)?.toInt ?: 0
    if (size <= nDegrees) return null

    // compute median
    median := this.median

    // compute Σ(xᵢ - median)
    sum := 0f
    for (i:=0; i<size; ++i)
    {
      sum += array[i] - median
    }

    // put it together
    mbe := 1f / (size - nDegrees) * sum;
    return mbe
  }
}

**************************************************************************
** FoldStandardDeviation
**************************************************************************

internal class FoldStandardDeviation : FoldMath
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  protected override Float? onFinish()
  {
    // compute mean
    mean := this.mean

    sumsq := 0f
    for (i:=0; i<size; ++i)
    {
      diff := array[i] - mean
      sumsq += diff * diff
    }

    // put it together
    stdDev := (sumsq / (size - 1)).sqrt
    return stdDev
  }
}

**************************************************************************
** FoldQuantile
**************************************************************************

internal class FoldQuantile : FoldMath
{
  new make(Bool axon, Dict meta) : super(axon, meta) { }
  protected override Float? onFinish()
  {
    if (size == 1) { return array[0] }
    array.sort(0..<size)

    // get percent
    perc := (meta.get("percent") as Number)?.toFloat ?: throw ArgErr("Quantile 'percent' not configured")

    // get rank (index of quantile)
    i := perc * (size - 1).toFloat
    k := i.toInt    // floor of i
    d := i - k      // diff between true i and floor Int

    // handle each method
    method := meta.get("method") ?: "unspecified"
    switch(method)
    {
      case "lower":    return array[k].toFloat
      case "higher":   return array[k + 1]
      case "nearest":  return array[i.round.toInt]
      case "midpoint": return ((array[k] + array[(k + 1).min(size - 1)]) / 2).toFloat
      case "linear":   return (array[k] + (array[(k + 1).min(size - 1)] - array[k]) * d).toFloat
      default: throw Err("Unexpected method type: ${method}")
    }
  }
}