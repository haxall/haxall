//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2015   Brian Frank   Creation
//

using xeto
using haystack

**
** MatrixTest
**
class MatrixTest : HaystackTest
{

//////////////////////////////////////////////////////////////////////////
// To Matrix
//////////////////////////////////////////////////////////////////////////

  Void testToMatrix()
  {
    verifyToMatrix(
      """ver:"2.0"
         v0,v1,v2
         1,2,3
         4,5,6""",
         [[1f,2f,3f],
          [4f,5f,6f]],
          false)

    verifyToMatrix(
      """ver:"2.0"
         v0,v1,v2
         1kW,2,3ft
         4kW,5,6ft""",
         [[1f,2f,3f],
          [4f,5f,6f]],
         true)
  }

  Void verifyToMatrix(Str zinc, Float[][] floats, Bool hasUnits)
  {
    grid := ZincReader(zinc.in).readGrid
    m := MatrixGrid(grid)
    verifyEq(m.numRows, floats.size)
    verifyEq(m.numCols, floats[0].size)
    floats.each |floatRow, rowi|
    {
      mRow := m.get(rowi)
      floatRow.each |float, coli|
      {
        verifyEq(float, m.float(rowi, coli))
        verifyEq(mRow.get("v$coli")->toFloat, float)
      }
    }
    if (!hasUnits) verifyGridEq(grid, m)
  }

//////////////////////////////////////////////////////////////////////////
// Test Match
//////////////////////////////////////////////////////////////////////////

  Void testMath()
  {
    a := toMatrix(
      """ver:"2.0"
         v0,v1,v2
         1,2,3
         4,5,6""")

    b := toMatrix(
      """ver:"2.0"
         v0,v1,v2
         10,20,30
         40,50,60""")

    c := toMatrix(
      """ver:"2.0"
         v0,v1
         7,8
         9,10
         11,12""")

    cu := toMatrix(
      """ver:"2.0" c
         v0,v1
         7m,8m
         9m,10m
         11m,12m""")

    // toMatrix
    d := toMatrix(
      """ver:"2.0"
         v0,v1
         1,2
         3,4
         N,NA""", Etc.makeDict(["nullVal": n(0), "naVal": n(1)]))
    verifyEq(n(0), d.get(2).get("v0"))
    verifyEq(n(1), d.get(2).get("v1"))

    // transpose

    verifyMatrixEq(a.transpose,
      """ver:"2.0"
         v0,v1
         1,4
         2,5
         3,6""")

    // add

    verifyMatrixEq(a + b,
      """ver:"2.0"
         v0,v1,v2
         11,22,33
         44,55,66""")

    // sub

    verifyMatrixEq(b - a,
      """ver:"2.0"
         v0,v1,v2
         9,18,27
         36,45,54""")

    // mult

    verifyMatrixEq(a * c,
      """ver:"2.0"
         v0,v1
         58,64
         139,154""")

    // multByConst

    verifyMatrixEq(a.multByConst(3f),
      """ver:"2.0"
         v0,v1,v2
         3,6,9
         12,15,18""")


    // insertCol

    verifyMatrixEq(a.insertCol(99f),
      """ver:"2.0"
         v0,v1,v2,v3
         99,1,2,3
         99,4,5,6""")

    // cofactor

    verifyMatrixEq(toMatrix(
      """ver:"2.0"
         v0,v1,v2
         1,2,3
         0,4,5
         1,0,6""").cofactor,
      """ver:"2.0"
         v0,v1,v2
         24,5,-4
         -12,3,2
         -2,-5,4""")
  }

  Void testDeterminant()
  {
    tol := 0.001f
    verifyEq(toMatrix(
      """ver:"2.0"
         v0
         5""").determinant, 5f)

    verifyEq(toMatrix(
      """ver:"2.0"
         v0,v1
         4,6
         3,8""").determinant, 14f)

    verifyEq(toMatrix(
      """ver:"2.0"
         v0,v1,v2
         6,1,1
         4,-2,5
         2,8,7""").determinant, -306f)

    verifyEq(toMatrix(
      """ver:"2.0"
         v0,v1,v2,v3
         -1,2,3,4
         5,-6,7,8
         9,10,-11,12
         13,14,15,-16""").determinant, -36416f)
  }

  Void testInverse()
  {
    verifyMatrixEq(toMatrix(
      """ver:"2.0"
         v0,v1
         4,7
         2,6""").inverse,
      """ver:"2.0"
         v0,v1
         0.6,-0.7
         -0.2,0.4""")

    verifyMatrixEq(toMatrix(
      """ver:"2.0"
         v0,v1,v2,v3
         -1,2,3,4
         5,-6,7,8
         9,10,-11,12
         13,14,15,-16""").inverse,
      """ver:"2.0"
         v0,v1,v2,v3
         -0.130492091388, 0.0601933216169, 0.0320738137083, 0.0215289982425
         0.118189806678, -0.0553602811951, 0.0197715289982, 0.0166959578207
         0.0953427065026, 0.0250439367311, -0.0268014059754, 0.0162565905097
         0.0867750439367, 0.0239455184534, 0.0182337434095, -0.0151581722320""")
  }

//////////////////////////////////////////////////////////////////////////
// Linear Regression
//////////////////////////////////////////////////////////////////////////

  Void testLinearRegression()
  {
    y := toMatrix(
      """ver:"2.0"
         v0
         27
         29
         23
         20
         21""")

    x := toMatrix(
      """ver:"2.0"
         v0,v1,v2
         4,0,1
         7,1,1
         6,1,0
         2,0,0
         3,0,1""")

    r := MatrixGrid.fitLinearRegression(y, x)
    // r.dump

    tol := 0.001f
    verifyNumApprox(r.meta->bias, 9.25f, tol)
    verifyEq(r.meta->ymean, n(24))
    verifyNumApprox(r.meta->r, 0.9464847243000456f, tol)
    verifyNumApprox(r.meta->r2, 0.8958333333333334f, tol)
    verifyEq(r.size, 3)
    verifyNumApprox(r[0]->b, 4.75f, tol)
    verifyNumApprox(r[1]->b, -13.5f, tol)
    verifyNumApprox(r[2]->b, -1.25f, tol)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  MatrixGrid toMatrix(Str zinc, Dict opts := Etc.dict0)
  {
    grid := ZincReader(zinc.in).readGrid
    return MatrixGrid(grid, opts)
  }

  Void verifyMatrixEq(MatrixGrid a, Obj b)
  {
    if (b is Str) b = toMatrix(b)
    verifyEq(a.numRows, b->numRows)
    verifyEq(a.numCols, b->numCols)
    a.numRows.times |i|
    {
      a.numCols.times |j|
      {
        aIJ := a.float(i, j)
        bIJ := b->float(i, j)
        if (!aIJ.approx(bIJ))
        {
          fail("cell ($i, $j) not approx. equal: $aIJ ~= $bIJ")
        }
      }
    }
    verify(true)
    /*
    echo("===============")
    a.dump
    b->dump
    */
    /*
    NOTE: do not use verifyGridEq because the values are Floats,
    and that results in DictHashKey not equal errors


    verifyGridEq(a, b)
    */
  }
}

