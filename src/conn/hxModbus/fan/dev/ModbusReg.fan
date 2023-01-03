//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Oct 2013  Brian Frank       Creation
//   14 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using haystack

**
** ModbusReg models one logical register point (may span
** multiple 16-bit words)
**
@Js const class ModbusReg
{
  ** It-block constructor
  new make(|This| f)
  {
    f(this)
    if (!Etc.isTagName(name)) throw Err("Invalid register name: $name")
    if (dis == null || dis.isEmpty) dis = name
    if (tags == null) tags = Etc.emptyDict
  }

  ** Programatic name of the register
  const Str name

  ** Display name of the register
  const Str dis

  ** Address
  const ModbusAddr addr

  ** Data
  const ModbusData data

  ** Number of 16-bit words required to hold register value.
  const Int size

  ** Can we read this regiter
  const Bool readable

  ** Can we write this register
  const Bool writable

  ** Scale factor
  const ModbusScale? scale

  ** Unit
  const Unit? unit

  ** Additional tags used for modeling the register as a point
  const Dict tags

  override Str toStr()
  {
    "$name [$dis] $addr $data"
  }
}

**************************************************************************
** ModbusAddrType
**************************************************************************

@Js const class ModbusAddr
{
  ** Parse 5 or 6 digit address where leading digit must be 0, 1, 3, 4
  ** to indicate type and next 4 or 5 digits represent register number
  static new fromStr(Str str)
  {
    if (str.size != 5 && str.size != 6) throw ParseErr("ModbusAddr wrong size: $str")
    type := ModbusAddrType.fromPrefixChar(str[0])
    num  := str[1..-1].toInt(10, false) ?: throw ParseErr("ModbusAddr not integer: $str")
    return make(type, num)
  }

  ** Make with explicit type and register number
  new make(ModbusAddrType type, Int num)
  {
    this.type = type
    this.num  = num
    this.qnum = toStr.toInt
  }

  ** 40123 maps to holdingReg
  const ModbusAddrType type

  ** 40123 maps to 123
  const Int num

  ** Qualified address which includes type prefix.
  const Int qnum

  ** Convert back to string
  override Str toStr()
  {
    s := StrBuf()
    s.addChar(type.toPrefixChar)
    if (num < 10) s.addChar('0')
    if (num < 100) s.addChar('0')
    if (num < 1000) s.addChar('0')
    s.add(num.toStr)
    return s.toStr
  }
}

**************************************************************************
** ModbusAddrType
**************************************************************************

@Js enum class ModbusAddrType
{
  coil,
  discreteInput,
  inputReg,
  holdingReg

  ** Is this type a boolean type (coil or discreteInput)?
  Bool isBool() { this==coil || this==discreteInput }

  ** Is this type a numberic type (inputReg or holdingReg)?
  Bool isNum() { this==inputReg || this==holdingReg }

  ** Map address prefix char 4, 3, 1, 0 to type
  internal static new fromPrefixChar(Int char)
  {
    if (char == '4') return holdingReg
    if (char == '3') return inputReg
    if (char == '1') return discreteInput
    if (char == '0') return coil
    throw ParseErr("ModbusAddrType invalid prefix digit: $char.toChar")
  }

  ** Back to address prefix 4, 3, 1, 0
  Int toPrefixChar()
  {
    if (this === holdingReg)    return '4'
    if (this === inputReg)      return '3'
    if (this === discreteInput) return '1'
    if (this === coil)          return '0'
    return '?'
  }

  ** Localized display name for type.
  Str toLocale()
  {
    switch (this)
    {
      case coil:          return "$<coil=Coil>"
      case discreteInput: return "$<discreteInput=Discrete Input>"
      case inputReg:      return "$<inputReg=Input Register>"
      case holdingReg:    return "$<holdingReg=Holding Register>"
      default: throw ArgErr()
    }
  }
}


**************************************************************************
** ModbusData
**************************************************************************

@Js abstract const class ModbusData
{
  private static const Str:ModbusData map := Str:ModbusData[:].setList(
  [
    ModbusBitData("bit"),
    ModbusBitData("bit:0"),
    ModbusBitData("bit:1"),
    ModbusBitData("bit:2"),
    ModbusBitData("bit:3"),
    ModbusBitData("bit:4"),
    ModbusBitData("bit:5"),
    ModbusBitData("bit:6"),
    ModbusBitData("bit:7"),
    ModbusBitData("bit:8"),
    ModbusBitData("bit:9"),
    ModbusBitData("bit:10"),
    ModbusBitData("bit:11"),
    ModbusBitData("bit:12"),
    ModbusBitData("bit:13"),
    ModbusBitData("bit:14"),
    ModbusBitData("bit:15"),

    ModbusIntData("u1"),
    ModbusIntData("u1le"),
    ModbusIntData("u1leb"),
    ModbusIntData("u1lew"),

    ModbusIntData("u2"),
    ModbusIntData("u2le"),
    ModbusIntData("u2leb"),
    ModbusIntData("u2lew"),

    ModbusIntData("u4"),
    ModbusIntData("u4le"),
    ModbusIntData("u4leb"),
    ModbusIntData("u4lew"),

    ModbusIntData("s1"),
    ModbusIntData("s1le"),
    ModbusIntData("s1leb"),
    ModbusIntData("s1lew"),

    ModbusIntData("s2"),
    ModbusIntData("s2le"),
    ModbusIntData("s2leb"),
    ModbusIntData("s2lew"),

    ModbusIntData("s4"),
    ModbusIntData("s4le"),
    ModbusIntData("s4leb"),
    ModbusIntData("s4lew"),

    ModbusIntData("s8"),
    ModbusIntData("s8le"),
    ModbusIntData("s8leb"),
    ModbusIntData("s8lew"),

    ModbusFloatData("f4"),
    ModbusFloatData("f4le"),
    ModbusFloatData("f4leb"),
    ModbusFloatData("f4lew"),

    ModbusFloatData("f8"),
    ModbusFloatData("f8le"),
    ModbusFloatData("f8leb"),
    ModbusFloatData("f8lew"),

  ]) |v| { v.name }

  ** Parse data model from string.
  static ModbusData? fromStr(Str s, Bool checked := true)
  {
    data := map[s]
    if (data == null)
    {
      if (!checked) return null
      throw ParseErr("Invalid data '$s'")
    }
    return data
  }

  ** Data name.
  abstract Str name()

  ** Kind for data.
  abstract Kind kind()

  ** Number of registers required to hold data.
  abstract Int size()

  ** Get value from raw register data.
  abstract Obj fromRegs(Int[] regs, Unit? unit := null)

  ** Convert value to register data.
  abstract Int[] toRegs(Obj val)

  override Int hash() { name.hash }
  override Bool equals(Obj? that) { name == (that as ModbusData)?.name }
  override Str toStr() { name }
}

**************************************************************************
** ModbusBitData
**************************************************************************

@Js const class ModbusBitData : ModbusData
{
  new make(Str name)
  {
    this.name = name
    if (name.contains(":")) this.pos = name["bit:".size..-1].toInt
    this.mask = 1.shiftl(pos)
  }
  override const Str name
  override const Kind kind := Kind.bool
  override const Int size := 1
  const Int pos := 0
  const Int mask
  override Obj fromRegs(Int[] regs, Unit? unit := null) { regs.first.and(mask) > 0 }
  override Int[] toRegs(Obj val) { [0] }
}

**************************************************************************
** ModbusNumData
**************************************************************************

@Js abstract const class ModbusNumData : ModbusData
{
  new make(Str name)
  {
    this.name = name
    this.base = name[0..1]
    switch (name[1])
    {
      case '1': this.size = 1
      case '2': this.size = 1
      case '4': this.size = 2
      case '8': this.size = 4
    }
    if (name.endsWith("le")) { wordBig = byteBig = false }  // little endian word + bytes
    else if (name.endsWith("lew")) wordBig = false          // little endian words
    else if (name.endsWith("leb")) byteBig = false          // little endian words
  }

  override const Str name
  const Str base
  override const Int size
  override const Kind kind := Kind.number
  const Bool wordBig := true
  const Bool byteBig := true

  protected Int toBits(Int[] regs)
  {
    // sanity check
    if (regs.size != size)
      throw ArgErr("Registers size mismatch $regs.size != $size")

    len  := regs.size - 1
    bits := 0
    regs.each |w,i|
    {
      if (!byteBig) w = swapBytes(w)
      if (wordBig) bits = bits.or(w.shiftl((len-i)*16))
      else bits = bits.or(w.shiftl(i*16))
    }

    return bits
  }

  protected Int[] fromBits(Int bits)
  {
    regs := Int[,]
    size.times |i|
    {
      w := bits.shiftr(i*16).and(0xffff)
      if (!byteBig) w = swapBytes(w)
      regs.add(w)
    }
    return wordBig ? regs.reverse : regs
  }

  private Int swapBytes(Int w)
  {
    w.and(0xff).shiftl(8).or(0xff.and(w.shiftr(8)))
  }
}

@Js const class ModbusIntData : ModbusNumData
{
  new make(Str name) : super(name) {}

  override Obj fromRegs(Int[] regs, Unit? unit := null)
  {
    bits := toBits(regs)
    val  := 0
    switch (base)
    {
      case "u1": val = bits.and(0xff)
      case "u2": val = bits.and(0xffff)
      case "u4": val = bits.and(0xffff_ffff)

      case "s1": val = bits.and(0xff); if (val.and(0x80) > 0) val += 0xffff_ffff_ffff_ff00
      case "s2": val = bits.and(0xffff); if (val.and(0x8000) > 0) val += 0xffff_ffff_ffff_0000
      case "s4": val = bits.and(0xffff_ffff); if (val.and(0x8000_0000) > 0) val += 0xffff_ffff_0000_0000
      case "s8": val = bits

      default: throw Err()
    }
    return Number.makeInt(val, unit)
  }

  override Int[] toRegs(Obj val)
  {
    if (val is Number) return fromBits(((Number)val).toInt)

    // these are only supported for doing writes; where the Addr
    // may not map to the actual register(s) width

    // for Num[] lists we map the value 1:1 per 16-bit register
    if (val is List)
    {
      ints := Int[,]
      ((List)val).each |n| { ints.add(((Number)n).toInt) }
      return ints
    }

    // for Str hex values we decode each 2-byte word per register
    if (val is Str)
    {
      buf := Buf.fromHex(val)
      if (buf.size % 2 != 0) throw ArgErr("Invalid hex string length")
      ints := Int[,]
      while (buf.remaining > 0) ints.add(buf.readU2)
      return ints
    }

    throw ArgErr("Invalid value ${val} [${val.typeof}]")
  }
}

@Js const class ModbusFloatData : ModbusNumData
{
  new make(Str name) : super(name) {}
  override Obj fromRegs(Int[] regs, Unit? unit := null)
  {
    bits := toBits(regs)
    if (base == "f4") return Number(Float.makeBits32(bits), unit)
    if (base == "f8") return Number(Float.makeBits(bits), unit)
    throw Err(base)
  }
  override Int[] toRegs(Obj val)
  {
    if (base == "f4") return fromBits(((Number)val).toFloat.bits32)
    if (base == "f8") return fromBits(((Number)val).toFloat.bits)
    throw Err(base)
  }
}

**************************************************************************
** ModbusScale
**************************************************************************

@Js const class ModbusScale
{
  new static fromStr(Str s, Bool checked := true)
  {
    try
    {
      op := s[0]
      if (!ops.contains(op)) throw Err("Invalid op 'op.toChar'")
      // val := s[1..-1].trim
      // factor := Number.fromStr(val, false)
      // name   := factor == null ? val : null
      factor := Number.fromStr(s[1..-1].trim)
      return ModbusScale
      {
        it.op = op
        it.factor = factor
        // it.name = name
      }
    }
    catch (Err err)
    {
      if (!checked) return null
      throw ParseErr("Invalid scale '$s'")
    }
  }

  ** Constructor.
  new make(|This| f) { f(this) }

  ** Scale operator
  const Int op

  ** Numeric scale factor
  //const Number? factor
  const Number factor

  // ** Reference register name to query factor
  // const Str? name

  ** Compute the scaled value.
  Number compute(Number in, Number? factor := null)
  {
    f := factor ?: this.factor
    switch (op)
    {
      case '+': return in + f
      case '-': return in - f
      case '*': return in * f
      case '/': return in / f
      default: throw Err()
    }
  }

  ** Compute inverse scale value.
  Number inverse(Number in, Number? factor := null)
  {
    f := factor ?: this.factor
    switch (op)
    {
      case '+': return in - f
      case '-': return in + f
      case '*': return in / f
      case '/': return in * f
      default: throw Err()
    }
  }

  private static const Int[] ops := ['+', '-', '*', '/']
}
