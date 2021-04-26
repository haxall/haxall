//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2012  Brian Frank  Create
//

using haystack

**
** CoordTest
**
@Js
class CoordTest : Test
{
  Void test()
  {
    doTest()
    Locale("fr").use { doTest }
  }

  Void doTest()
  {
    verifyCoord(12f, 34f, "C(12.0,34.0)")

    // lat boundaries
    verifyCoord(90f, 123f, "C(90.0,123.0)")
    verifyCoord(-90f, 123f, "C(-90.0,123.0)")
    verifyCoord(89.888999f, 123f, "C(89.888999,123.0)")
    verifyCoord(-89.888999f, 123f, "C(-89.888999,123.0)")

    // lon boundaries
    verifyCoord(45f, 180f, "C(45.0,180.0)")
    verifyCoord(45f, -180f, "C(45.0,-180.0)")
    verifyCoord(45f, 179.999129f, "C(45.0,179.999129)")
    verifyCoord(45f, -179.999129f, "C(45.0,-179.999129)")

    // decimal places
    verifyCoord(9.1f, -8.1f, "C(9.1,-8.1)")
    verifyCoord(9.12f, -8.13f, "C(9.12,-8.13)")
    verifyCoord(9.123f, -8.134f, "C(9.123,-8.134)")
    verifyCoord(9.1234f, -8.1346f, "C(9.1234,-8.1346)")
    verifyCoord(9.12345f,- 8.13456f, "C(9.12345,-8.13456)")
    verifyCoord(9.123452f, -8.134567f, "C(9.123452,-8.134567)")

    // zero boundaries
    verifyCoord(0f, 0f, "C(0.0,0.0)")
    verifyCoord(0.3f, -0.3f, "C(0.3,-0.3)")
    verifyCoord(0.03f, -0.03f, "C(0.03,-0.03)")
    verifyCoord(0.003f, -0.003f, "C(0.003,-0.003)")
    verifyCoord(0.0003f, -0.0003f, "C(0.0003,-0.0003)")
    verifyCoord(0.02003f, -0.02003f, "C(0.02003,-0.02003)")
    verifyCoord(0.020003f, -0.020003f, "C(0.020003,-0.020003)")
    verifyCoord(0.000123f, -0.000123f, "C(0.000123,-0.000123)")
    verifyCoord(7.000123f, -7.000123f, "C(7.000123,-7.000123)")

    // arg errors
    verifyErr(ArgErr#) { x := Coord(91f, 12f) }
    verifyErr(ArgErr#) { x := Coord(-90.2f, 12f) }
    verifyErr(ArgErr#) { x := Coord(13f, 180.009f) }
    verifyErr(ArgErr#) { x := Coord(13f, -181f) }
    verifyErr(ArgErr#) { x := Coord.makeu(90_000_001, 0) }
    verifyErr(ArgErr#) { x := Coord.makeu(-90_000_001, 0) }
    verifyErr(ArgErr#) { x := Coord.makeu(0, 180_000_001) }
    verifyErr(ArgErr#) { x := Coord.makeu(0, -180_000_001) }

    // parse errs
    verifyNull(Coord("1.0,2.0", false))
    verifyErr(ParseErr#) { x := Coord("1.0,2.0") }
    verifyErr(ParseErr#) { x := Coord("(1.0,2.0)") }
    verifyErr(ParseErr#) { x := Coord("C(1.0,2.0") }
  }

  Void verifyCoord(Float lat, Float lng, Str s)
  {
    c := Coord(lat, lng)
    //echo("---> $c 0x" + c.pack.toHex)
    verifyEq(c.lat, lat)
    verifyEq(c.lng, lng)
    verifyEq(c.toStr, s)
    verifyEq(Coord(s), c)
    verifyEq(Coord(c.toStr), c)
    verifyEq(Coord.unpack(c.pack), c)
    verifyEq(Coord.unpack(c.pack).pack, c.pack)
    x := StrBuf() { out.writeObj(c) }.toStr
    verifyEq(x.in.readObj, c)
  }

  Void testDist()
  {
    dist := Coord("C(38.881468,-77.024495)").dist(Coord("C(37.539190,-77.433049)"))
    verifyEq(dist.toFloat.floor, 153463f)
  }
}