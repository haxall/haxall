//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2012  Brian Frank  Creation
//

**
** Geographic coordinate as latitude and longitute in decimal degrees.
**
@Js
@Serializable { simple = true }
const final class Coord
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Default value is "C(0.0,0.0)"
  const static Coord defVal := Coord(0, 0)

  ** Decode from string formatted as "C(lat,lng)"
  static new fromStr(Str s, Bool checked := true)
  {
    try
    {
      if (!s.startsWith("C(") || !s.endsWith(")")) throw Err()
      comma := s.index(",", 3)
      return make(s[2..<comma].toFloat, s[comma+1..<-1].toFloat)
    }
    catch (Err e) {}
    if (checked) throw ParseErr("Coor: $s")
    return null
  }

  ** Construct from floating point decimal degrees
  new make(Float lat, Float lng)
  {
    // store as micro-degrees
    this.ulat = (lat * 1_000_000f).toInt
    this.ulng = (lng * 1_000_000f).toInt
    if (ulat < -90_000_000 || ulat > 90_000_000) throw ArgErr("Invalid lat > +/- 90")
    if (ulng < -180_000_000 || ulng > 180_000_000) throw ArgErr("Invalid lng > +/- 180")
  }

  ** Construct from decimal micro-degrees
  @NoDoc static Coord makeu(Int ulat, Int ulng) { makeuImpl(ulat, ulng) }

  private new makeuImpl(Int ulat, Int ulng)
  {
    this.ulat = ulat
    this.ulng = ulng
    if (ulat < -90_000_000 || ulat > 90_000_000) throw ArgErr("Invalid lat > +/- 90")
    if (ulng < -180_000_000 || ulng > 180_000_000) throw ArgErr("Invalid lng > +/- 180")
  }

//////////////////////////////////////////////////////////////////////////
// Access
//////////////////////////////////////////////////////////////////////////

  ** Latitude in decimal degrees
  Float lat() { ulat.toFloat / 1_000_000f }

  ** Longtitude in decimal degrees
  Float lng() { ulng.toFloat / 1_000_000f }

  ** Latitude in micro-degrees
  @NoDoc const Int ulat

  ** Longitude in micro-degrees
  @NoDoc const Int ulng

  ** Hash is based on lat/lng
  override Int hash() { pack }

  ** Equality is based on lat/lng
  override Bool equals(Obj? that)
  {
    x := that as Coord
    if (x == null) return false
    return ulat == x.ulat && ulng == x.ulng
  }

  ** Represented as  "C(lat,lng)"
  override Str toStr()
  {
    s := StrBuf()
    s.add("C(")
    uToStr(s, ulat)
    s.addChar(',')
    uToStr(s, ulng)
    s.add(")")
    return s.toStr
  }

  ** Represented as "lat,lng" without "C(...)"
  @NoDoc Str toLatLgnStr()
  {
    s := StrBuf()
    uToStr(s, ulat)
    s.addChar(',')
    uToStr(s, ulng)
    return s.toStr
  }

  private Void uToStr(StrBuf s, Int ud)
  {
    if (ud < 0) { s.addChar('-'); ud = -ud }
    if (ud < 1_000_000)
    {
      Locale("en-US").use
      {
        s.add((ud.toFloat / 1_000_000f).toLocale("0.0#####"))
      }
      return
    }
    x := ud.toStr
    dot := x.size - 6
    end := x.size
    while (end > dot+1 && x[end-1] == '0') --end
    for (i:=0; i<dot; ++i) s.addChar(x[i])
    s.addChar('.')
    for (i:=dot; i<end; ++i) s.addChar(x[i])
  }

//////////////////////////////////////////////////////////////////////////
// 64-Bit Int Packing
//////////////////////////////////////////////////////////////////////////

  **
  ** Pack into a 64-bit integer which is encoded as:
  **   lat+90 in micro-degrees << 32-bits | lng+180 in micro-degrees
  **
  @NoDoc Int pack()
  {
    (ulat + 90_000_000).and(0xfff_ffff).shiftl(32).or((ulng+180_000_000).and(0xffff_ffff))
  }

  ** Unpack froma 64-bit integer - see `pack`
  @NoDoc static Coord unpack(Int bits)
  {
    makeu(bits.shiftr(32).and(0xfff_ffff) - 90_000_000,
          bits.and(0xffff_ffff) - 180_000_000)
  }

//////////////////////////////////////////////////////////////////////////
// Math
//////////////////////////////////////////////////////////////////////////

  ** Compute great-circle distance two coordinates using haversine forumula.
  Float dist(Coord c2)
  {
    c1 := this
    r := 6371 // km
    dLat := (c2.lat - c1.lat).toRadians.div(2f).sin
    dLng := (c2.lng - c1.lng).toRadians.div(2f).sin
    lat1 := c1.lat.toRadians.cos
    lat2 := c2.lat.toRadians.cos
    a := (dLat * dLat) + (dLng * dLng * lat1 * lat2)
    c := 2f * Float.atan2(a.sqrt, (1f-a).sqrt)
    d := r * c;
    return d * 1000f
  }
}


