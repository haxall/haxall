//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2015   Brian Frank   Creation
//

using xeto
using haystack
using math
using util

**
** MatrixGrid models a two dimensional grid of unitless Numbers.
** It wraps a Fantom 'math::Matrix' instance.
**
const class MatrixGrid : Grid
{
  ** Construct from a grid of Numbers.  Columns are named
  ** "v0", "v1", etc.  We maintain grid meta, but not column meta.
  new makeGrid(Grid grid, Dict opts := Etc.dict0)
  {
    this.meta = grid.meta

    cols := grid.cols
    m    := Math.matrix(grid.size, cols.size)
    grid.each |row,rowi|
    {
      cols.each |col,coli|
      {
        val := row.val(col)
        if (val == null) val = opts.get("nullVal")
        else if (val === NA.val) val = opts.get("naVal")
        num := val as Number
        if (num == null) throw Err("Grid cell ($rowi, $col.name) not a number: ${val?.typeof}")
        m.set(rowi, coli, num.toFloat)
      }
    }
    this.matrixRef = Unsafe(m)
    this.rows = MatrixRow.makeList(this)
    this.cols = toCols(cols.size)
  }

  internal new makeMatrix(Dict meta, Matrix matrix)
  {
    this.meta = meta
    this.matrixRef = Unsafe(matrix)
    this.rows = MatrixRow.makeList(this)
    this.cols = toCols(matrix.numCols)
  }

  private static Col[] toCols(Int numCols)
  {
    if (numCols < MatrixCol.list.size)
      return MatrixCol.list[0..<numCols]
    else
    {
      arr := MatrixCol.list.dup
      (MatrixCol.list.size..<numCols).each |n| { arr.add(MatrixCol(n)) }
      return arr
    }
  }

//////////////////////////////////////////////////////////////////////////
// Matrix Access
//////////////////////////////////////////////////////////////////////////

  ** Backing matrix
  private Matrix matrix() { matrixRef.val }
  private const Unsafe matrixRef

  ** Number of rows in matrix
  Int numRows() { matrix.numRows }

  ** Number of cols in matrix
  Int numCols() { matrix.numCols }

  ** Is this a square matrix where numRows == numCols
  Bool isSquare() { matrix.isSquare }

  ** Get floating point value for given cell in matrix
  Float float(Int row, Int col) { matrix.get(row, col) }

  ** Get Number value for given cell in matrix
  Number? number(Int row, Int col)
  {
    f := float(row, col)
    return Number(f)
  }

//////////////////////////////////////////////////////////////////////////
// Grid
//////////////////////////////////////////////////////////////////////////

  const override Dict meta
  override const Col[] cols
  override Col? col(Str name, Bool checked := true)
  {
    i   := name[1..-1].toInt(10, false)
    col := null
    if (i != null) col = cols.getSafe(i)
    if (col != null) return col
    if (checked) throw UnknownNameErr(name)
    return null
  }
  override Void each(|Row,Int| f) { rows.each(f) }
  override Obj? eachWhile(|Row,Int->Obj?| f) { rows.eachWhile(f) }
  override Int size() { rows.size }
  override Row get(Int index) { rows[index] }
  override Row? getSafe(Int index) { rows.getSafe(index) }
  override Row? first() { rows.first }
  override Row[] toRows() { rows }
  private const MatrixRow[] rows

//////////////////////////////////////////////////////////////////////////
// Math Operations
//////////////////////////////////////////////////////////////////////////

  ** Transpose
  override MatrixGrid transpose() { MatrixGrid(meta, matrix.transpose) }

  ** Multily each cell by given constant
  MatrixGrid multByConst(Float x)
  {
    m := Math.matrix(numRows, numCols)
    for (r:=0; r<numRows; ++r)
      for (c:=0; c<numCols; ++c)
        m.set(r, c, float(r,c)*x)
    return MatrixGrid(meta, m)
  }

  ** Insert column at leftmost position and fill with given value.
  MatrixGrid insertCol(Float val)
  {
    aNumCols := numCols+1
    m := Math.matrix(numRows, aNumCols)
    for (r:=0; r<numRows; ++r)
    {
      m.set(r, 0, val)
      for (c:=0; c<numCols; ++c)
        m.set(r, c+1, float(r, c))
    }
    return MatrixGrid(meta, m)
  }

  ** Add two matrices together (must be of same dimension)
  @Operator MatrixGrid plus(MatrixGrid b) { MatrixGrid(meta, matrix.plus(b.matrix)) }

  ** Subtract two matrices together (must be of same dimension)
  @Operator MatrixGrid minus(MatrixGrid b) { MatrixGrid(meta, matrix.minus(b.matrix)) }

  ** Multiply two matrices together
  @Operator MatrixGrid mult(MatrixGrid b) { MatrixGrid(meta, matrix.mult(b.matrix)) }

  ** Determinant
  Float determinant() { matrix.determinant }

  ** Cofactor
  MatrixGrid cofactor() { MatrixGrid(meta, matrix.cofactor) }

  ** Inverse
  MatrixGrid inverse() { MatrixGrid(meta, matrix.inverse) }

//////////////////////////////////////////////////////////////////////////
// Linear Regression
//////////////////////////////////////////////////////////////////////////

  //
  // This code originally authored by John MacEnri,
  // <john.macenri@crowleycarbon.com>, copyright assigned
  // to SkyFoundry
  //

  ** Perform multiple linear regression using the 2 provided matrices.
  ** Y is expected to only have one column and it contains the dependent values.
  ** X will have as many columns as there are correlating factors.
  ** Y and X must have the same number of rows.
  ** X cannot have more columns that it has rows.
  static Grid fitLinearRegression(MatrixGrid Y, MatrixGrid X)
  {
    if (X.numCols >  X.numRows) throw Err("The number of columns in X matrix cannot be more than the number of rows");
    if (X.numRows != Y.numRows) throw Err("The number of rows in X matrix should be the same as the number of rows in Y matrix");

    //Using bias always
    Xic := X.insertCol(1f)
    Xtr := Xic.transpose
    XtrX := Xtr.mult(Xic)
    invXtrX := XtrX.inverse
    XtrY := Xtr.mult(Y)
    B := invXtrX.mult(XtrY)

    Ycalc := FloatArray.makeF8(Y.numRows)
    ymean := 0.0f
    for (i := 0; i < Y.numRows; i++)
    {
      yCalcVal := B.float(0,0)
      for (j := 0; j < X.numCols; j++) yCalcVal += B.float(j+1,0) * X.float(i,j)
      Ycalc.set(i,yCalcVal)
      ymean += Y.float(i,0)
    }
    ymean = ymean/Y.numRows

    // solve for coefficient of determination
    //   SStot = Σ (yᵢ - ymean)²
    //   SSerr = Σ (yᵢ - yᵣ)²
    //   R²    = 1 - SSerr / SStot
    SStot := 0f
    SSerr := 0f
    for (i := 0; i < Y.numRows; i++)
    {
      yrdiff := Y.float(i,0) - Ycalc.get(i)
      ymdiff := Y.float(i,0) - ymean
      SStot += ymdiff * ymdiff
      SSerr += yrdiff * yrdiff
    }
    r2 := 1f - SSerr/SStot
    r := r2.sqrt

    gb := GridBuilder()
    gb.setMeta([
      "r":Number(r),
      "r2":Number(r2),
      "ymean":Number(ymean),
      "rowCount":Number(Y.numRows),
      "bias":Number(B.float(0,0))])
    gb.addCol("b")
    for (i := 1; i < B.numRows; i++)
      gb.addRow1(Number(B.float(i,0)))

    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  static FloatArray arrayMake(Int numRows, Int numCols) { FloatArray.makeF8(numRows*numCols) }

  static Int index(Int numCols, Int row, Int col) { row * numCols + col }
}

**************************************************************************
** MatrixCol
**************************************************************************

internal const class MatrixCol : Col
{
  ** Predefined instances from v0 up to v99
  static const MatrixCol[] list

  static
  {
    accList := MatrixCol[,]
    accMap := Str:MatrixCol[:]
    100.times |i| { col := MatrixCol(i); accList.add(col); accMap[col.name] = col }
    list = accList
  }

  new make(Int index) { this.name = "v"+index; this.index = index }

  override const Str name
  override Dict meta() { Etc.dict0 }
  const Int index // col index
}

**************************************************************************
** MatrixRow
**************************************************************************

internal const class MatrixRow : Row
{
  static MatrixRow[] makeList(MatrixGrid m)
  {
    acc := MatrixRow[,]
    acc.capacity = m.numRows
    m.numRows.times |i| { acc.add(MatrixRow(m, i)) }
    return acc
  }

  new make(MatrixGrid grid, Int index) { this.grid = grid; this.index = index }
  override const MatrixGrid grid
  const Int index // row index
  override Obj? val(Col col) { grid.number(index, ((MatrixCol)col).index) }
}

