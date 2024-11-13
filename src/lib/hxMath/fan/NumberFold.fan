//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Feb 2012   Brian Frank   Creation
//

using haystack
using util

**
** NumberFold is used to keep track of an entire series of Numbers
** during a fold operation.  It uses a FloatArray for efficient
** storage and also keeps track of unit.
**
internal class NumberFold
{
  Int size
  FloatArray array := FloatArray.makeF8(1024)
  Unit? unit

  @Operator Float get(Int index) { array[index] }

  Bool isEmpty() { size == 0 }

  This add(Number? val)
  {
    if (val == null) return this
    if (unit == null) unit = val.unit
    if (size == array.size)
    {
      grow := FloatArray.makeF8(array.size*2)
      grow.copyFrom(array)
      array = grow
    }
    array[size++] = val.toFloat
    return this
  }

  Float mean()
  {
    if (isEmpty) throw Err("NumberFold is empty")
    sum := 0f
    for (i:=0; i<size; ++i) sum += array[i]
    return sum/size.toFloat
  }

  Float median()
  {
    if (isEmpty) throw Err("NumberFold is empty")
    array.sort(0..<size)
    if (size.isOdd) return array[size/2]
    a := array[size/2-1]
    b := array[size/2]
    return (a+b)/2f
  }

  //quantile method
  Float quantile(Float? perc, Str? method)
  {

    if (size == 1) { return array[0] }
    array.sort(0..<size)

    //get rank (index of quantile)
    i := perc * (size - 1).toFloat
    k := i.toInt    // floor of i
    d := i - k      // diff between true i and floor Int

    //handle each method
    switch(method)
    {
      case "lower":    return array[k].toFloat
      case "higher":   return array[k + 1]
      case "nearest":  return array[i.round.toInt]
      case "midpoint": return ((array[k] + array[(k + 1).min(size - 1)]) / 2).toFloat
      case "linear":   return (array[k] + (array[(k + 1).min(size - 1)] - array[k]) * d).toFloat
      default: throw Err("Unexpected method type")
    }
  }
}
