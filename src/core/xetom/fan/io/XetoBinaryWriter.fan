//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** Writer for Xeto binary encoding of specs and data.
**
** This encoding does not provide full fidelity with Xeto model.  Most
** scalars are encoded as just a string.  However it does support some
** types not supported by Haystack fidelity level such as Int, Float, Buf.
**
** NOTE: this encoding is not backward/forward compatible - it only works
** with XetoBinaryReader of the same version; do not use for persistent data
**
@Js
class XetoBinaryWriter : XetoBinaryConst
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(OutStream out)
  {
    this.out = out
    this.cp = BrioConsts.cur
  }

//////////////////////////////////////////////////////////////////////////
// Lib
//////////////////////////////////////////////////////////////////////////

  Void writeLibs(XetoLib[] libs)
  {
    // write debug first line in plain text
    out.print("libpack:")
    libs.each |lib| { out.print(lib.name).print(";") }
    out.printLine

    // binary encoding
    writeVarInt(libs.size)
    libs.each |lib| { writeLib(lib) }
  }

  Void writeLib(XetoLib lib)
  {
    writeI4(magicLib)
    writeStr(lib.name)
    writeDict(lib.m.meta)
    writeVarInt(lib.m.flags)
    writeSpecs(lib)
    writeInstances(lib)
    writeI4(magicLibEnd)
  }

  private Void writeSpecs(XetoLib lib)
  {
    specs := lib.specs
    writeVarInt(specs.size)
    lib.specs.each |x| { writeSpec(x) }
  }

  private Void writeSpec(XetoSpec x)
  {
    m := x.m
    writeStr(m.name)
    write(m.flavor.ordinal)
    writeSpecRef(m.base)
    writeSpecRef(m.isType ? null : m.type)
    writeDict(m.metaOwn)
    writeInheritedMetaNames(x)
    writeOwnSlots(x)
    writeVarInt(m.flags)
    if (!x.isCompound && !x.isNone) write(XetoBinaryConst.specOwnOnly)
    else
    {
      // for and/or types we encoded inherited meta/slots to
      // avoid duplicating that complicated logic in the client
      write(XetoBinaryConst.specInherited)
      writeDict(m.meta)
      writeInheritedSlotRefs(x)
    }
  }

  private Void writeInheritedMetaNames(XetoSpec x)
  {
    own := x.metaOwn
    x.meta.each |v, n|
    {
      if (own.missing(n)) writeStr(n)
    }
    writeStr("")
  }

  private Void writeOwnSlots(XetoSpec x)
  {
    map := x.m.slotsOwn.map
    size := map.size
    writeVarInt(size)
    map.each |slot| { writeSpec(slot) }
  }

  private Void writeInheritedSlotRefs(XetoSpec x)
  {
    x.slots.each |slot|
    {
      if (x.slotOwn(slot.name, false) != null) return
      writeSpecRef(slot)
    }
    writeSpecRef(null)
  }

  private Void writeSpecRef(XetoSpec? spec)
  {
    if (spec == null) { write(0); return }
    if (spec.parent == null)
    {
      write(1)
      writeStr(spec.lib.name)
      writeStr(spec.name)
    }
    else if (spec.parent.parent == null)
    {
      write(2)
      writeStr(spec.lib.name)
      writeStr(spec.parent.name)
      writeStr(spec.name)
    }
    else
    {
      path := Str[,]
      for (Spec? x := spec; x != null; x = x.parent)
        path.add(x.name)
      path.reverse
      write(path.size + 1)
      writeStr(spec.m.lib.name)
      path.each |n| { writeStr(n) }
    }
  }

  private Void writeInstances(XetoLib lib)
  {
    instances := lib.m.instancesMap
    writeVarInt(instances.size)
    lib.m.instancesMap.each |x| { writeDict(x) }
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  Void writeVal(Obj? val)
  {
    // haystack
    if (val == null)         return writeNull
    if (val === Marker.val)  return writeMarker
    if (val === NA.val)      return writeNA
    if (val === Remove.val)  return writeRemove
    type := val.typeof
    if (type === Str#)      return writeStr(val)
    if (type === Number#)   return writeNumber(val)
    if (type === Ref#)      return writeRef(val)
    if (type === DateTime#) return writeDateTime(val)
    if (val is Buf)         return writeBuf(val)
    if (val is Dict)        return writeDict(val)
    if (val is List)        return writeList(val)
    if (type === Bool#)     return writeBool(val)
    if (type === Date#)     return writeDate(val)
    if (type === Time#)     return writeTime(val)
    if (type === Uri#)      return writeUri(val)
    if (type === Coord#)    return writeCoord(val)
    if (val is Grid)        return writeGrid(val)
    if (val is Span)        return writeSpan(val)
    if (type === Scalar#)   return writeGenericScalar(val)

    // non-haystack
    if (type === Int#)      return writeInt(val)
    if (type === Float#)    return writeFloat(val)
    if (type === Duration#) return writeDuration(val)
    if (type === Version#)  return writeVersion(val)

    writeTypedScalar(val)
  }

  private Void writeNull()
  {
    write(ctrlNull)
  }

  private Void writeMarker()
  {
    write(ctrlMarker)
  }

  private Void writeNA()
  {
    write(ctrlNA)
  }

  private Void writeRemove()
  {
    write(ctrlRemove)
  }

  private Void writeBool(Bool val)
  {
    write(val ? ctrlTrue : ctrlFalse)
  }

  private This writeNumber(Number val)
  {
    unit := val.unit?.symbol
    if (unit == null)
    {
      write(ctrlNumberNoUnit)
      writeF8(val.toFloat)
    }
    else
    {
      write(ctrlNumberUnit)
      writeF8(val.toFloat)
      writeStr(unit)
    }
    return this
  }

  private Void writeInt(Int val)
  {
    if (-32767 <= val && val <= 32767)
    {
      write(ctrlInt2)
      writeI2(val)
    }
    else
    {
      write(ctrlInt8)
      writeI8(val)
    }
  }

  private Void writeFloat(Float val)
  {
    write(ctrlFloat8)
    writeF8(val)
  }

  private Void writeDuration(Duration val)
  {
    write(ctrlDuration)
    writeI8(val.ticks)
  }

  private Void writeUri(Uri uri)
  {
    write(ctrlUri)
    writeStr(uri.toStr)
  }

  private Void writeRef(Ref ref)
  {
    write(ctrlRef)
    writeStr(ref.id)
    writeStr(ref.disVal ?: "")
  }

  private This writeDate(Date val)
  {
    write(ctrlDate)
    out.writeI2(val.year).write(val.month.ordinal+1).write(val.day)
    return this
  }

  private This writeTime(Time val)
  {
    write(ctrlTime)
    writeI4(val.toDuration.ticks / 1ms.ticks)
    return this
  }

  private This writeDateTime(DateTime val)
  {
    write(ctrlDateTime)
    out.writeI2(val.year).write(val.month.ordinal+1).write(val.day)
    out.write(val.hour).write(val.min).write(val.sec).writeI2(val.nanoSec / 1ms.ticks)
    writeStr(val.tz.name)
    return this
  }

  private This writeBuf(Buf buf)
  {
    write(ctrlBuf)
    writeVarInt(buf.size)
    out.writeBuf(buf.seek(0))
    return this
  }

  private This writeSpan(Span span)
  {
    out.write(ctrlSpan)
    writeStr(span.toStr)
    return this
  }

  private This writeVersion(Version val)
  {
    write(ctrlVersion)
    segs := val.segments
    writeVarInt(segs.size)
    for (i:=0; i<segs.size; ++i) writeVarInt(segs[i])
    return this
  }

  private This writeCoord(Coord val)
  {
    write(ctrlCoord)
    writeStr(val.toStr)
    return this
  }

  private This writeGenericScalar(Scalar val)
  {
    out.write(ctrlGenericScalar)
    writeStr(val.qname)
    writeStr(val.val)
    return this
  }

  private This writeTypedScalar(Obj val)
  {
    out.write(ctrlTypedScalar)
    writeStr(val.typeof.qname)
    writeStr(val.toStr)
    return this
  }

  Void writeDict(Dict d)
  {
    if (d.isEmpty)        return write(ctrlEmptyDict)
    if (d is XetoSpec)    return writeSpecRefVal(d)
    if (isGenericDict(d)) return writeGenericDict(d)
    return writeTypedDict(d)
  }

  private Bool isGenericDict(Dict d)
  {
    podName := d.typeof.pod.name
    if (podName == "haystack") return true
    return false
  }

  private Void writeSpecRefVal(XetoSpec spec)
  {
    write(ctrlSpecRef)
    writeSpecRef(spec)
  }

  private Void writeGenericDict(Dict dict)
  {
    write(ctrlGenericDict)
    writeDictTags(dict)
  }

  private Void writeTypedDict(Dict dict)
  {
    write(ctrlTypedDict)
    writeStr(dict.typeof.qname)
    writeDictTags(dict)
  }

  private Void writeDictTags(Dict dict)
  {
    dict.each |v, n|
    {
      writeStr(n)
      writeVal(v)
    }
    writeStr("")
  }

  Void writeList(Obj?[] list)
  {
    write(ctrlList)
    writeVarInt(list.size)
    list.each |x|
    {
      writeVal(x)
    }
  }

  Void writeGrid(Grid grid)
  {
    write(ctrlGrid)

    cols := grid.cols
    writeVarInt(cols.size)
    writeVarInt(grid.size)

    writeDict(grid.meta)
    cols.each |col|
    {
      writeStr(col.name)
      writeDict(col.meta)
    }
    grid.each |row|
    {
      cols.each |c| { writeVal(row.val(c)) }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Strings
//////////////////////////////////////////////////////////////////////////

  Void writeStr(Str val)
  {
    // check brio string constant pool
    code := cp.encode(val, constMaxCode)
    if (code != null)
    {
      write(ctrlStrConst)
      writeVarInt(code)
      return
    }

    // string we havea already encoded in this string
    index := strs[val]
    if (index != null)
    {
      write(ctrlStrPrev)
      writeVarInt(index)
      return
    }

    // new string from stream
    //BrioConstTrace.trace(val)
    strs[val] = strs.size
    write(ctrlStrNew)
    size := val.size
    writeVarInt(size)
    val.each |char| { out.writeChar(char) }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void write(Int byte)
  {
    out.write(byte)
  }

  Void writeI2(Int i)
  {
    out.writeI2(i)
  }

  Void writeI4(Int i)
  {
    out.writeI4(i)
  }

  Void writeI8(Int i)
  {
    out.writeI8(i)
  }

  Void writeF8(Float f)
  {
    out.writeF8(f)
  }

  Void writeRawRefList(Ref[] ids)
  {
    writeVarInt(ids.size)
    ids.each |id| { writeStr(id.id) }
  }

  Void writeRawDictList(Dict[] dicts)
  {
    writeVarInt(dicts.size)
    dicts.each |d| { writeDict(d) }
  }

  Void writeVarInt(Int val)
  {
    // see BrioWriter.encodeVarInt - same encoding
    if (val < 0) return out.write(0xff)
    if (val <= 0x7f) return out.write(val)
    if (val <= 0x3fff) return out.writeI2(val.or(0x8000))
    if (val <= 0x1fff_ffff) return out.writeI4(val.or(0xc000_0000))
    return out.write(0xe0).writeI8(val)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private static const Int constMaxCode := 1000

  private OutStream out
  private BrioConsts cp
  private Str:Int strs := Str:Int[:]
}

