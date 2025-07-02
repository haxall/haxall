//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 May 2019  Brian Frank  Creation
//

using xeto
using haystack
using def

**
** CProto models a prototype instance from a definition's children tags
**
class CProto
{
  ** Construction
  internal new make(Str hashKey, Dict dict, CDef[] implements)
  {
    this.hashKey     = hashKey
    this.dict        = dict
    this.dis         = encode(dict, false)
    this.docName     = toDocName(dict)
    this.implements  = implements
  }

  static Str toHashKey(Dict d) { encode(d, true) }

  private static Str encode(Dict d, Bool sort)
  {
    s := StrBuf()
    names := Str[,]
    d.each |v, n| { names.add(n) }
    if (sort) names.sort
    names.each |n|
    {
      v := d[n]
      if (v == null) return
      if (!s.isEmpty) s.addChar(' ')
      s.add(n)
      if (v != Marker.val) s.addChar(':').add(ZincWriter.valToStr(v))
    }
    return s.toStr
  }

  private static Str toDocName(Dict d)
  {
    s := StrBuf()
    first := true
    d.each |v, n|
    {
      if (first) first = false; else s.addChar('-')
      s.add(n)
      if (v != Marker.val) s.addChar('~').add(ZincWriter.valToStr(v).toBuf.toHex)
    }
    return s.toStr
  }

  ** Prototype tags from Namespace.proto
  const Dict dict

  ** Unique hash key without regard to tag ordering
  const Str hashKey

  ** Display string for prototype tags
  const Str dis

  ** Location if not derived during auto-generation
  CLoc? loc

  ** Definitions implemented by this prototype
  CDef[] implements

  ** Children of the prototype based on implemented defs (set after make)
  CProto[]? children

  ** String representation
  override Str toStr() { dis }

  ** Encoded name for documentation file
  const Str docName

  ** Set loc field is not null
  internal This setLoc(CLoc? x) { if (x != null) loc = x; return this }

  ** If run thru GenDocEnv
  DocProto? doc

}

