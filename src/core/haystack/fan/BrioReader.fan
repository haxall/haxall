//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Nov 2015  Brian Frank  Creation
//

**
** BrioReader deserializes Haystack data using a binary format.
**
@NoDoc
class BrioReader : GridReader, BrioCtrl
{

  new make(InStream in)
  {
    this.in = in
    this.cp = BrioConsts.cur
  }

  override Grid readGrid() { readVal }

  Bool close() { in.close }

  Int avail() { in.avail }

  Dict readDict() { readVal }

  Obj? readVal()
  {
    ctrl := in.readU1
    switch (ctrl)
    {
      case ctrlNull:       return null
      case ctrlMarker:     return Marker.val
      case ctrlNA:         return NA.val
      case ctrlRemove:     return Remove.val
      case ctrlFalse:      return false
      case ctrlTrue:       return true
      case ctrlNumberI2:   return consumeNumberI2
      case ctrlNumberI4:   return consumeNumberI4
      case ctrlNumberF8:   return consumeNumberF8
      case ctrlStr:        return consumeStr
      case ctrlRefStr:     return consumeRefStr
      case ctrlRefI8:      return consumeRefI8
      case ctrlUri:        return consumeUri
      case ctrlDate:       return consumeDate
      case ctrlTime:       return consumeTime
      case ctrlDateTimeI4: return consumeDateTimeI4
      case ctrlDateTimeI8: return consumeDateTimeI8
      case ctrlCoord:      return consumeCoord
      case ctrlXStr:       return consumeXStr
      case ctrlBuf:        return consumeBuf
      case ctrlDictEmpty:  return Etc.emptyDict
      case ctrlDict:       return consumeDict
      case ctrlListEmpty:  return Obj?#.emptyList
      case ctrlList:       return consumeList
      case ctrlGrid:       return consumeGrid
      case ctrlSymbol:     return consumeSymbol
      default:             throw IOErr("obj ctrl 0x$ctrl.toHex")
    }
  }

  private Number consumeNumberI2()
  {
    Number(in.readS2, consumeUnit)
  }

  private Number consumeNumberI4()
  {
    Number(in.readS4, consumeUnit)
  }

  private Number consumeNumberF8()
  {
    Number(in.readF8, consumeUnit)
  }

  private Unit? consumeUnit()
  {
    s := decodeStr(false)
    if (s.isEmpty) return null
    return Number.loadUnit(s)
  }

  private Str consumeStr()
  {
    internStr(decodeStr(true))
  }

  private Ref consumeRefStr()
  {
    internRef(decodeStr(false), decodeStrChars(false))
  }

  private Ref consumeRefI8()
  {
    internRef(Ref.makeHandle(in.readS8).id, decodeStrChars(false))
  }

  private Symbol consumeSymbol()
  {
    internSymbol(decodeStr(false))
  }

  private Uri consumeUri()
  {
    Uri.fromStr(decodeStr(false))
  }

  private Date consumeDate()
  {
    internDate(Date(in.readU2, Month.vals[in.read-1], in.read))
  }

  private Time consumeTime()
  {
    Time.fromDuration(Duration(in.readU4 * 1ms.ticks))
  }

  private DateTime consumeDateTimeI4()
  {
    DateTime.makeTicks(in.readS4*1sec.ticks, consumeTimeZone)
  }

  private DateTime consumeDateTimeI8()
  {
    DateTime.makeTicks(in.readS8, consumeTimeZone)
  }

  private TimeZone consumeTimeZone() { TimeZone.fromStr(decodeStr(false)) }

  private Coord consumeCoord()
  {
    Coord.unpack(in.readS8)
  }

  private Obj consumeXStr()
  {
    type := decodeStr(true)
    val  := decodeStr(true)
    return XStr.decode(type, val)
  }

  private Buf consumeBuf()
  {
    size := decodeVarInt
    return in.readBufFully(null, size).toImmutable
  }

  private Obj?[] consumeList()
  {
    verifyByte('[')
    size := decodeVarInt
    acc := Obj?[,]
    acc.capacity = size
    for (i := 0; i<size; ++i)
    {
      val := readVal
      acc.add(val)
    }
    verifyByte(']')
    return Kind.toInferredList(acc)
  }

  private Dict consumeDict()
  {
    verifyByte('{')
    count := decodeVarInt
    acc := Str:Obj[:]
    for (i:=0; i<count; ++i)
    {
      tag := decodeStr(true)
      val := readVal
      acc[tag] = val
    }
    verifyByte('}')
    return Etc.makeDict(acc)
  }

  private Grid consumeGrid()
  {
    verifyByte('<')
    numCols := decodeVarInt
    numRows := decodeVarInt

    gb := GridBuilder()
    gb.capacity = numRows
    gb.setMeta(readDict)
    for (c:=0; c<numCols; ++c)
    {
      gb.addCol(decodeStr(true), readDict)
    }
    for (r:=0; r<numRows; ++r)
    {
      cells := Obj?[,]
      cells.size = numCols
      for (c:=0; c<numCols; ++c)
        cells[c] = readVal
      gb.addRow(cells)
    }

    verifyByte('>')
    return gb.toGrid
  }

  Str decodeStr(Bool intern)
  {
    code := decodeVarInt
    if (code >= 0) return cp.decode(code)
    return decodeStrChars(intern)
  }

  Str decodeStrChars(Bool intern)
  {
    size := decodeVarInt
    s := StrBuf()
    s.capacity = size
    for (i := 0; i<size; ++i)
      s.addChar(in.readChar)
    str := s.toStr
    if (intern) str = internStr(str)
    return str
  }

  Int decodeVarInt()
  {
    v := in.readU1
    if (v == 0xff)           return -1
    if (v.and(0x80) == 0)    return v
    if (v.and(0xc0) == 0x80) return v.and(0x3f).shiftl(8).or(in.readU1)
    if (v.and(0xe0) == 0xc0) return v.and(0x1f).shiftl(8).or(in.readU1).shiftl(16).or(in.readU2)
    return in.readS8
  }

  virtual Str internStr(Str v)
  {
    if (internStrs == null) internStrs = Str:Str[:]
    intern := internStrs[v]
    if (intern == null) internStrs[v] = intern = v
    return intern
  }

  virtual Ref internRef(Str id, Str? dis)
  {
    if (dis.isEmpty) dis = null
    v := Ref.makeImpl(id, dis)
    if (internRefs == null) internRefs = Ref:Ref[:]
    intern := internRefs[v]
    if (intern == null) internRefs[v] = intern = v
    return intern
  }

  virtual Symbol internSymbol(Str v)
  {
    if (internSymbols == null) internSymbols = Str:Symbol[:]
    intern := internSymbols[v]
    if (intern == null) internSymbols[v] = intern = Symbol.parse(v)
    return intern
  }

  virtual Date internDate(Date v)
  {
    if (internDates == null) internDates = Date:Date[:]
    intern := internDates[v]
    if (intern == null) internDates[v] = intern = v
    return intern
  }

  private Void verifyByte(Int b)
  {
    x := in.readU1
    if (x != b) throw IOErr("Unexpected byte: 0x$x.toHex '$x.toChar' != 0x$b.toHex '$b.toChar'")
  }

  InStream in
  private const BrioConsts cp
  private [Str:Str]? internStrs
  private [Ref:Ref]? internRefs
  private [Str:Symbol]? internSymbols
  private [Date:Date]? internDates
}