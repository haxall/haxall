//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Feb 2012   Brian Frank   Creation
//   7  Nov 2024   James Gessel  Add percentile funcs

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

  //general percentile method 
  sys::Float percentile(sys::Float perc) {
    if (perc < 0f || perc > 1f) {
        throw Err("Percentile must be between 0 and 1")
    }
    if (isEmpty) {
        throw Err("NumberFold is empty")
    }
    array.sort(0..<size) //sort array 

    if (size == 1) { return array[0] }

    //get index of percentile 
    i := perc * (size - 1).toFloat
    k := i.toInt    // floor of i
    d := i - k      // diff between true i and floor Int

    //return indexed perc number
    //interpolate if needed
    if (k >= size - 1) {
        return array[k].toFloat
    } else {
        a := array[k]
        b := array[k + 1]
        return (a * (1 - d) + b * d).toFloat
    }
}

  Float percentile1() { percentile(0.01f) }
  Float percentile5() { percentile(0.05f) }
  Float percentile25() { percentile(0.25f) }
  Float percentile75() { percentile(0.75f) }
  Float percentile95() { percentile(0.95f) }
  Float percentile99() { percentile(0.99f) }

}
