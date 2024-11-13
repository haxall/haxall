//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Dec 2010   Brian Frank   Creation
//

using math
using util
using haystack
using axon
using hx

**
** Axon functions for math
**
const class MathFuncs
{

//////////////////////////////////////////////////////////////////////////
// Constants
//////////////////////////////////////////////////////////////////////////

  *** Return constant for pi: 3.141592653589793
  @Axon static Number pi() { piVal }
  private static const Number piVal := Number(Float.pi)

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Return the remainder or modulo of division: 'a % b'.
  ** Result has same unit as 'a'.
  @Axon static Number remainder(Number a, Number b) { Number(a.toFloat % b.toFloat, a.unit) }

  ** Return the smallest whole number greater than or equal to val.
  ** Result has same unit as 'val'.
  @Axon static Number ceil(Number val) { Number(val.toFloat.ceil, val.unit) }

  ** Return the largest whole number less than or equal to val.
  ** Result has same unit as 'val'.
  @Axon static Number floor(Number val) { Number(val.toFloat.floor, val.unit) }

  ** Returns the nearest whole number to val.
  ** Result has same unit as 'val'.
  @Axon static Number round(Number val) { Number(val.toFloat.round, val.unit) }

  ** Return e raised to val.
  @Axon static Number exp(Number val) { Number(val.toFloat.exp) }

  ** Return natural logarithm to the base e of val.
  @Axon static Number logE(Number val) { Number(val.toFloat.log) }

  ** Return base 10 logarithm of val.
  @Axon static Number log10(Number val) { Number(val.toFloat.log10) }

  ** Return val raised to the specified power.
  @Axon static Number pow(Number val, Number exp) { Number(val.toFloat.pow(exp.toFloat)) }

  ** Return square root of val.
  @Axon static Number sqrt(Number val) { Number(val.toFloat.sqrt) }

  ** Return random integer within given inclusive range.
  ** If range is null, then full range of representative
  ** integers is assumed.
  **
  ** Examples:
  **    random()       // random num with no range
  **    random(0..100) // random num between 0 and 100
  @Axon static Number random(Obj? range := null)
  {
    r := range == null ?
         -2251799813685248..2251799813685248 :
         ((ObjRange)range).toIntRange
    return Number.makeInt(r.random)
  }

//////////////////////////////////////////////////////////////////////////
// Bitwise
//////////////////////////////////////////////////////////////////////////

  ** Bitwise not: '~a'
  @Axon static Number bitNot(Number a) { Number.makeInt(a.toInt.not) }

  ** Bitwise and: 'a & b'
  @Axon static Number bitAnd(Number a, Number b) { Number.makeInt(a.toInt.and(b.toInt)) }

  ** Bitwise or: 'a | b'
  @Axon static Number bitOr(Number a, Number b) { Number.makeInt(a.toInt.or(b.toInt)) }

  ** Bitwise xor: 'a ^ b'
  @Axon static Number bitXor(Number a, Number b) { Number.makeInt(a.toInt.xor(b.toInt)) }

  ** Bitwise right shift: 'a >> b'
  @Axon static Number bitShiftr(Number a, Number b) { Number.makeInt(a.toInt.shiftr(b.toInt)) }

  ** Bitwise left shift: 'a << b'
  @Axon static Number bitShiftl(Number a, Number b) { Number.makeInt(a.toInt.shiftl(b.toInt)) }

//////////////////////////////////////////////////////////////////////////
// Trig
//////////////////////////////////////////////////////////////////////////

  ** Return the arc cosine.
  @Axon static Number acos(Number val) { Number(val.toFloat.acos) }

  ** Return the arc sine.
  @Axon static Number asin(Number val) { Number(val.toFloat.asin) }

  ** Return the arc tangent.
  @Axon static Number atan(Number val) { Number(val.toFloat.atan) }

  ** Converts rectangular coordinates (x, y) to polar (r, theta).
  @Axon static Number atan2(Number y, Number x) { Number(Float.atan2(y.toFloat, x.toFloat)) }

  ** Return the cosine of angle in radians.
  @Axon static Number cos(Number val) { Number(val.toFloat.cos) }

  ** Return the hyperbolic cosine.
  @Axon static Number cosh(Number val) { Number(val.toFloat.cosh) }

  ** Return sine of angle in radians.
  @Axon static Number sin(Number val) { Number(val.toFloat.sin) }

  ** Return hyperbolic sine.
  @Axon static Number sinh(Number val) { Number(val.toFloat.sinh) }

  ** Return tangent of angle in radians.
  @Axon static Number tan(Number val) { Number(val.toFloat.tan) }

  ** Return hyperbolic tangent.
  @Axon static Number tanh(Number val) { Number(val.toFloat.tanh) }

  ** Convert angle in radians to an angle in degrees.
  @Axon static Number toDegrees(Number val) { Number(val.toFloat.toDegrees) }

  ** Convert angle in degrees to an angle in radians.
  @Axon static Number toRadians(Number val) { Number(val.toFloat.toRadians) }

//////////////////////////////////////////////////////////////////////////
// Folding Functions
//////////////////////////////////////////////////////////////////////////

  **
  ** Fold a sample of numbers into their standard average or arithmetic
  ** mean.  This function is the same as [core::avg]`avg()`.  Nulls
  ** values are ignored.  Return null if no values.
  **
  ** Example:
  **   [2, 4, 5, 3].fold(mean)
  **
  @Axon { meta = ["foldOn":"Number", "disKey":"ui::mean"] }
  static Obj? mean(Obj? val, Obj? acc)
  {
    CoreLib.avg(val, acc)
  }

  **
  ** Fold a sample of numbers into their median value which is the
  ** middle value of the sorted samples.  If there are an even number
  ** of sample, then the median is the mean of the middle two.  Null
  ** values are ignored.  Return null if no values.
  **
  ** Example:
  **   [2, 4, 5, 3, 1].fold(median)
  **
  @Axon { meta = ["foldOn":"Number", "disKey":"ui::median"] }
  static Obj? median(Obj? val, Obj? acc)
  {
    if (val === NA.val || acc === NA.val) return NA.val
    fold := acc as NumberFold
    if (val === CoreLib.foldStart) return NumberFold()
    if (val !== CoreLib.foldEnd)  return fold.add(val)
    if (fold.isEmpty) return null
    return Number(fold.median, fold.unit)
  }

  **
  ** Fold a sample of numbers into their RMSE (root mean square error).
  ** The RMSE function determines the RMSE between a sample set and
  ** its mean using the n-degrees of freedom RMSE:
  **
  **   RMBE = sqrt( Σ(xᵢ - median)² ) / (n - nDegrees)
  **
  ** Examples:
  **   samples.fold(rootMeanSquareErr)         // unbiased zero degrees of freedom
  **   samples.fold(rootMeanSquareErr(_,_,1))  // 1 degree of freedom
  **
  @Axon { meta = ["foldOn":"Number", "disKey":"ui::rootMeanSquareErr"] }
  static Obj? rootMeanSquareErr(Obj? val, Obj? acc, Number nDegrees := Number.zero)
  {
    if (val === NA.val || acc === NA.val) return NA.val
    fold := acc as NumberFold
    if (val === CoreLib.foldStart) return NumberFold()
    if (val !== CoreLib.foldEnd)  return fold.add(val)

    // this function came from PNL, but I'm not sure its
    // quite correct because it uses median as the "truth"
    // value which seems hokey

    // compute median
    if (fold.isEmpty) return null
    median := fold.median

    // is sample size smaller than degrees of freedom return null
    if (fold.size <= nDegrees.toInt) return null

    // compute Σ(xᵢ - median)²
    sumsq := 0f
    for (i:=0; i<fold.size; ++i)
    {
      diff := fold[i] - median
      sumsq += diff * diff
    }

    // put it together
    rmse := 1f / (fold.size - nDegrees.toInt) * sumsq.sqrt;
    return Number(rmse, fold.unit)
  }

  **
  ** Fold a sample of numbers into their MBE (mean bias error).
  ** The MBE function determines the MBE between a sample set and
  ** its mean:
  **
  **   MBE = Σ(xᵢ - median) / (n - nDegrees)
  **
  ** Examples:
  **   samples.fold(meanBiasErr)         // unbiased zero degrees of freedom
  **   samples.fold(meanBiasErr(_,_,1))  // 1 degree of freedom
  **
  @Axon { meta = ["foldOn":"Number", "disKey":"ui::meanBiasErr"] }
  static Obj? meanBiasErr(Obj? val, Obj? acc, Number nDegrees := Number.zero)
  {
    if (val === NA.val || acc === NA.val) return NA.val
    fold := acc as NumberFold
    if (val === CoreLib.foldStart) return NumberFold()
    if (val !== CoreLib.foldEnd)  return fold.add(val)

    // this function came from PNL, but I'm not sure its
    // quite correct because it uses median as the "truth"
    // value which seems hokey

    // compute median
    if (fold.isEmpty) return null
    median := fold.median

    // is sample size smaller than degrees of freedom return null
    if (fold.size <= nDegrees.toInt) return null

    // compute Σ(xᵢ - median)
    sum := 0f
    for (i:=0; i<fold.size; ++i)
    {
      sum += fold[i] - median
    }

    // put it together
    mbe := 1f / (fold.size - nDegrees.toInt) * sum;
    return Number(mbe, fold.unit)
  }

  **
  ** Fold a series of numbers into the standard deviation of a *sample*:
  **
  **   s = sqrt(Σ (xᵢ - mean)² / (n-1))
  **
  ** Example:
  **   [4, 2, 5, 8, 6].fold(standardDeviation)
  **
  @Axon { meta = ["foldOn":"Number", "disKey":"ui::standardDeviation"] }
  static Obj? standardDeviation(Obj? val, Obj? acc)
  {
    if (val === NA.val || acc === NA.val) return NA.val
    fold := acc as NumberFold
    if (val === CoreLib.foldStart) return NumberFold()
    if (val !== CoreLib.foldEnd)  return fold.add(val)

    // compute mean
    if (fold.isEmpty) return null
    mean := fold.mean

    sumsq := 0f
    for (i:=0; i<fold.size; ++i)
    {
      diff := fold[i] - mean
      sumsq += diff * diff
    }

    // put it together
    stdDev := (sumsq / (fold.size - 1)).sqrt
    return Number(stdDev, fold.unit)
  }


  **
  ** Computes the p*th* quantile of a list of numbers, according to the specified interpolation method.
  ** The value p must be a number between 0.0 to 1.0.
  **
  **  - **linear** (default): Interpolates proportionally between the two closest values
  **  - **nearest**: Rounds to the nearest data point
  **  - **lower**: Rounds to the nearest lower data point
  **  - **higher**: Rounds to the nearest higher data point
  **  - **midpoint**: Averages two nearest values
  **
  ** Usage: [1,2,3].fold(quantile(p, method))
  **
  ** Examples:
  **   [10,10,10,25,100].fold(quantile(0.7 )) => 22 //default to linear
  **   [10,10,10,25,100].fold(quantile(0.7, "nearest")) => 25
  **   [10,10,10,25,100].fold(quantile(0.7, "lower")) => 10
  **   [10,10,10,25,100].fold(quantile(0.7, "higher")) => 25
  **   [10,10,10,25,100].fold(quantile(0.7, "linear")) => 22 //same as no arg
  **   [10,10,10,25,100].fold(quantile(0.7, "midpoint")) => 17.5
  **
  ** Detailed Logic:
  **    p: percentile (decimal 0-1)
  **    n: list size
  **    rank: p * (n-1) // this is the index of the percentile in your list
  **    // if rank is an integer, return list[rank]
  **    // if rank is not an integer, interpolate via one of the above methods (illustrated below in examples)
  **
  **    [1,2,3,4,5].percentile(0.5) => 3 // rank=2 is an int so we can index[2] directly
  **
  **    [10,10,10, 25, 100].percentile(0.7, method)
  **      rank = (0.7 * 4) => 2.8
  **
  **      //adjust rank based on method
  **      nearest =  index[3]                // => 25
  **      lower =    index[2]                // => 10
  **      higher =   index[3]                // => 25
  **
  **      //or interpolate for these methods
  **
  **      //takes the 2 closest indices and calculates midpoint
  **      midpoint = (25-10)/2 + 10          // => 17.5
  **
  **      //takes the 2 closest indices and calculates weighted average
  **      linear =   (0.2 * 10) + (0.8 * 25) // => 22
  **
  @Axon
  static Obj? quantile(Number percent, Str method := "linear")
  {
    //check boundaries
    perc := percent.toFloat
    if (perc < 0f || perc > 1f) throw ArgErr("Percent must be between 0-1")

    //this needs to return an axon::Fn equivalent to quantileFold(_,_,perc)
    return AxonContext.curAxon.evalToFunc("quantileFold(_,_,${percent}, \"${method}\")")
  }

  //the above func is a wrapper which takes a number percent and calls
  //this which does the calcs
  @NoDoc @Axon
  static Obj? quantileFold(Obj? val, Obj? acc, Number perc, Str method)
  {
    if (val === NA.val || acc === NA.val) return NA.val
    fold := acc as NumberFold
    if (val === CoreLib.foldStart) return NumberFold()
    if (val !== CoreLib.foldEnd)   return fold.add(val)
    if (fold.isEmpty)              return null

    Number? out := Number(fold.quantile(perc.toFloat, method), fold.unit)
    return out
  }

//////////////////////////////////////////////////////////////////////////
// Matrix
//////////////////////////////////////////////////////////////////////////

  **
  ** Convert a general grid to an optimized matrix grid.  Matrixs are two
  ** dimensional grids of Numbers.  Columns are named "v0", "v1", "v2", etc.
  ** Grid meta is preserved, but not column meta.  Numbers in the resulting
  ** matrix are unitless; any units passed in are stripped.
  **
  ** The following options are supported:
  ** - nullVal (Number): replace null values in the grid with this value
  ** - naVal (Number): replace NA values in the grid with this value
  **
  ** pre>
  **   toMatrix(grid, {nullVal: 0, naVal: 0})
  ** <pre
  **
  ** To create a sparse or initialized matrix you can pass a Dict with the
  ** the following tags (all required)
  **   toMatrix({rows:10, cols: 1000, init: 0})
  **
  @Axon static MatrixGrid toMatrix(Obj obj, Dict opts := Etc.emptyDict)
  {
    if (obj is MatrixGrid) return obj
    if (obj is Grid) return MatrixGrid.makeGrid(obj, opts)
    if (obj is Dict)
    {
      nrows  := (((Dict)obj)["rows"] as Number)?.toInt ?: throw ArgErr("Invalid rows: $obj")
      ncols  := (((Dict)obj)["cols"] as Number)?.toInt ?: throw ArgErr("Invalid cols: $obj")
      init   := (((Dict)obj)["init"] as Number)?.toFloat ?: throw ArgErr("Invalid init: $obj")
      matrix := Math.matrix(nrows, ncols).fill(init)
      return MatrixGrid(Etc.emptyDict, matrix)
    }
    throw Err("Unsupported toMatrix type: $obj.typeof")
  }

  **
  ** Transpose the given matrix which is any value accepted by `toMatrix`.
  **
  @Axon static MatrixGrid matrixTranspose(Obj m)
  {
    toMatrix(m).transpose
  }

  **
  ** Return the determinant as a unitless Number for the given matrix which
  ** is any value accepted by `toMatrix`.  The matrix must be square.
  **
  @Axon static Number matrixDeterminant(Obj m)
  {
    Number(toMatrix(m).determinant)
  }

  **
  ** Return the inverse of the given matrix which is any value accepted by `toMatrix`.
  **
  @Axon static MatrixGrid matrixInverse(Obj m)
  {
    toMatrix(m).inverse
  }

  **
  ** Add two matrices together and return new matrix.  The parameters may
  ** be any value supported `toMatrix`.  Matrices must have the same dimensions.
  **
  @Axon static MatrixGrid matrixAdd(Obj a, Obj b)
  {
    toMatrix(a) + toMatrix(b)
  }

  **
  ** Subtract two matrices and return new matrix.  The parameters may
  ** be any value supported `toMatrix`.  Matrices must have the same dimensions.
  **
  @Axon static MatrixGrid matrixSub(Obj a, Obj b)
  {
    toMatrix(a) - toMatrix(b)
  }

  **
  ** Multiply two matrices and return new matrix.  The parameters may
  ** be any value supported `toMatrix`.  Matrix 'a' column count must match
  ** matrix 'b' row count.
  **
  @Axon static MatrixGrid matrixMult(Obj a, Obj b)
  {
    toMatrix(a) * toMatrix(b)
  }

  **
  ** Given a matrix of y coordinates and a matrix of multiple x coordinates
  ** compute the best fit multiple linear regression equation using
  ** the ordinary least squares method.  Both 'y' and 'x' may be any value
  ** accepted by `toMatrix`.
  **
  ** The resulting linear equation for r X coordinates is:
  **
  **   yᵢ = bias + b₁xᵢ₁ + b₂xᵢ₂ +...+ bᵣxᵢᵣ
  **
  ** The equation is returned as a grid.  The grid meta:
  **   - 'bias': bias or zero coefficient which is independent of any of the x factors
  **   - 'r2':  R² coefficient of determination as a number between 1.0 (perfect correlation) and 0.0 (no correlation)
  **   - 'r': the square root of R², referred to as the correlation coefficient
  **   - 'rowCount': the number of rows of data used in the correlation
  ** For each X factor there is a row with the following tags:
  **   - 'b': the correlation coefficient for the given X factor
  **
  @Axon static Grid matrixFitLinearRegression(Obj y, Obj x)
  {
    MatrixGrid.fitLinearRegression(toMatrix(y), toMatrix(x))
  }

//////////////////////////////////////////////////////////////////////////
// Regression
//////////////////////////////////////////////////////////////////////////

  **
  ** Given a grid of x, y coordinates compute the best fit linear
  ** regression equation using the ordinary least squares method.
  ** The first column of the grid is used for 'x' and the second
  ** column is 'y'.  Any rows without a Number for both x and y
  ** are skipped.  Any special Numbers (infinity/NaN) are skipped.
  **
  ** Options:
  **   - 'x': column name to use for x if not first column
  **   - 'y': column name to use for y if not second column
  **
  ** The resulting linear equation is:
  **
  **   yᵢ = mxᵢ + b
  **
  ** The equation is returned as a dictionary with these keys:
  **   - 'm': slope of the best fit regression line
  **   - 'b': intercept of the best fit regression line
  **   - 'r2':  R² coefficient of determination as a number between
  **     1.0 (perfect correlation) and 0.0 (no correlation)
  **   - 'xmin': minimum value of x variable in sample data
  **   - 'xmax': maximum value of x variable in sample data
  **   - 'ymin': minimum value of y variable in sample data
  **   - 'ymax': maximum value of y variable in sample data
  **
  ** Also see `matrixFitLinearRegression` to compute a multiple linear
  ** regression.
  **
  ** Example:
  **   data: [{x:1, y:2},
  **          {x:2, y:4},
  **          {x:4, y:4},
  **          {x:6, y:5}].toGrid
  **    fitLinearRegression(data)
  **
  **    >>> {m:0.4915, b: 2.1525, r2: 0.7502}
  **
  @Axon
  static Dict fitLinearRegression(Grid grid, Dict? opts := null)
  {
    // transform grid into point list, which calculates our x, y means
    points := MathPointList(grid, opts)
    xmean := points.xmean
    ymean := points.ymean

    // solve for best fit linear regression
    //  sumxy  = Σ (xᵢ - xmean) (yᵢ - ymean)
    //  sumx2  = Σ (xᵢ - xmean)²
    //  m      = sumxy / sumx2
    //  b      = ymean - m*xmean
    sumxy := 0f
    sumx2 := 0f
    xmin  := Float.posInf; xmax  := Float.negInf
    ymin  := Float.posInf; ymax  := Float.negInf
    points.each |pt|
    {
      xdiff := pt.x - xmean
      ydiff := pt.y - ymean
      sumxy += xdiff * ydiff
      sumx2 += xdiff * xdiff
      xmin = xmin.min(pt.x); xmax = xmax.max(pt.x)
      ymin = ymin.min(pt.y); ymax = ymax.max(pt.y)
    }
    m := sumxy / sumx2
    b := ymean - (m * xmean)

    // solve for coefficient of determination
    //   SStot = Σ (yᵢ - ymean)²
    //   SSerr = Σ (yᵢ - yᵣ)²
    //   R²    = 1 - SSerr / SStot
    SStot := 0f
    SSerr := 0f
    points.each |pt|
    {
      yrdiff := pt.y - (m*pt.x + b)
      ymdiff := pt.y - ymean
      SStot += ymdiff * ymdiff
      SSerr += yrdiff * yrdiff
    }
    r2 := 1f - SSerr/SStot

    // return {m, b, r2} dict
    return Etc.makeDict(["m": Number(m), "b": Number(b), "r2":Number(r2),
                         "xmin": Number(xmin), "xmax": Number(xmax),
                         "ymin": Number(ymin), "ymax": Number(ymax)])
  }

}

