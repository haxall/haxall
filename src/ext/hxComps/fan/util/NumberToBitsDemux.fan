//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Aug 2025  Matthew Giannini  Creation
//

using xeto
using haystack

**
** Takes a 64-bit number (converted to an Int) and sets the various output bits accordingly.
** It also sets the corresponding bytes outputs.
**
@Gen
class NumberToBitsDemux : HxComp
{
  ** The input number
  @Gen virtual StatusNumber? in() { get("in") }

  ** Bit 0
  @Gen virtual StatusBool? bit0() { get("bit0") }

  ** Bit 1
  @Gen virtual StatusBool? bit1() { get("bit1") }

  ** Bit 2
  @Gen virtual StatusBool? bit2() { get("bit2") }

  ** Bit 3
  @Gen virtual StatusBool? bit3() { get("bit3") }

  ** Bit 4
  @Gen virtual StatusBool? bit4() { get("bit4") }

  ** Bit 5
  @Gen virtual StatusBool? bit5() { get("bit5") }

  ** Bit 6
  @Gen virtual StatusBool? bit6() { get("bit6") }

  ** Bit 7
  @Gen virtual StatusBool? bit7() { get("bit7") }

  ** Bit 8
  @Gen virtual StatusBool? bit8() { get("bit8") }

  ** Bit 9
  @Gen virtual StatusBool? bit9() { get("bit9") }

  ** Bit 10
  @Gen virtual StatusBool? bit10() { get("bit10") }

  ** Bit 11
  @Gen virtual StatusBool? bit11() { get("bit11") }

  ** Bit 12
  @Gen virtual StatusBool? bit12() { get("bit12") }

  ** Bit 13
  @Gen virtual StatusBool? bit13() { get("bit13") }

  ** Bit 14
  @Gen virtual StatusBool? bit14() { get("bit14") }

  ** Bit 15
  @Gen virtual StatusBool? bit15() { get("bit15") }

  ** Bit 16
  @Gen virtual StatusBool? bit16() { get("bit16") }

  ** Bit 17
  @Gen virtual StatusBool? bit17() { get("bit17") }

  ** Bit 18
  @Gen virtual StatusBool? bit18() { get("bit18") }

  ** Bit 19
  @Gen virtual StatusBool? bit19() { get("bit19") }

  ** Bit 20
  @Gen virtual StatusBool? bit20() { get("bit20") }

  ** Bit 21
  @Gen virtual StatusBool? bit21() { get("bit21") }

  ** Bit 22
  @Gen virtual StatusBool? bit22() { get("bit22") }

  ** Bit 23
  @Gen virtual StatusBool? bit23() { get("bit23") }

  ** Bit 24
  @Gen virtual StatusBool? bit24() { get("bit24") }

  ** Bit 25
  @Gen virtual StatusBool? bit25() { get("bit25") }

  ** Bit 26
  @Gen virtual StatusBool? bit26() { get("bit26") }

  ** Bit 27
  @Gen virtual StatusBool? bit27() { get("bit27") }

  ** Bit 28
  @Gen virtual StatusBool? bit28() { get("bit28") }

  ** Bit 29
  @Gen virtual StatusBool? bit29() { get("bit29") }

  ** Bit 30
  @Gen virtual StatusBool? bit30() { get("bit30") }

  ** Bit 31
  @Gen virtual StatusBool? bit31() { get("bit31") }

  ** Bit 32
  @Gen virtual StatusBool? bit32() { get("bit32") }

  ** Bit 33
  @Gen virtual StatusBool? bit33() { get("bit33") }

  ** Bit 34
  @Gen virtual StatusBool? bit34() { get("bit34") }

  ** Bit 35
  @Gen virtual StatusBool? bit35() { get("bit35") }

  ** Bit 36
  @Gen virtual StatusBool? bit36() { get("bit36") }

  ** Bit 37
  @Gen virtual StatusBool? bit37() { get("bit37") }

  ** Bit 38
  @Gen virtual StatusBool? bit38() { get("bit38") }

  ** Bit 39
  @Gen virtual StatusBool? bit39() { get("bit39") }

  ** Bit 40
  @Gen virtual StatusBool? bit40() { get("bit40") }

  ** Bit 41
  @Gen virtual StatusBool? bit41() { get("bit41") }

  ** Bit 42
  @Gen virtual StatusBool? bit42() { get("bit42") }

  ** Bit 43
  @Gen virtual StatusBool? bit43() { get("bit43") }

  ** Bit 44
  @Gen virtual StatusBool? bit44() { get("bit44") }

  ** Bit 45
  @Gen virtual StatusBool? bit45() { get("bit45") }

  ** Bit 46
  @Gen virtual StatusBool? bit46() { get("bit46") }

  ** Bit 47
  @Gen virtual StatusBool? bit47() { get("bit47") }

  ** Bit 48
  @Gen virtual StatusBool? bit48() { get("bit48") }

  ** Bit 49
  @Gen virtual StatusBool? bit49() { get("bit49") }

  ** Bit 50
  @Gen virtual StatusBool? bit50() { get("bit50") }

  ** Bit 51
  @Gen virtual StatusBool? bit51() { get("bit51") }

  ** Bit 52
  @Gen virtual StatusBool? bit52() { get("bit52") }

  ** Bit 53
  @Gen virtual StatusBool? bit53() { get("bit53") }

  ** Bit 54
  @Gen virtual StatusBool? bit54() { get("bit54") }

  ** Bit 55
  @Gen virtual StatusBool? bit55() { get("bit55") }

  ** Bit 56
  @Gen virtual StatusBool? bit56() { get("bit56") }

  ** Bit 57
  @Gen virtual StatusBool? bit57() { get("bit57") }

  ** Bit 58
  @Gen virtual StatusBool? bit58() { get("bit58") }

  ** Bit 59
  @Gen virtual StatusBool? bit59() { get("bit59") }

  ** Bit 60
  @Gen virtual StatusBool? bit60() { get("bit60") }

  ** Bit 61
  @Gen virtual StatusBool? bit61() { get("bit61") }

  ** Bit 62
  @Gen virtual StatusBool? bit62() { get("bit62") }

  ** Bit 63
  @Gen virtual StatusBool? bit63() { get("bit63") }

  ** Byte 0
  @Gen virtual StatusNumber? byte0() { get("byte0") }

  ** Byte 1
  @Gen virtual StatusNumber? byte1() { get("byte1") }

  ** Byte 2
  @Gen virtual StatusNumber? byte2() { get("byte2") }

  ** Byte 3
  @Gen virtual StatusNumber? byte3() { get("byte3") }

  ** Byte 4
  @Gen virtual StatusNumber? byte4() { get("byte4") }

  ** Byte 5
  @Gen virtual StatusNumber? byte5() { get("byte5") }

  ** Byte 6
  @Gen virtual StatusNumber? byte6() { get("byte6") }

  ** Byte 7
  @Gen virtual StatusNumber? byte7() { get("byte7") }

  override Void onExecute()
  {
    val    := in?.num?.toInt
    status := in?.status

    // update bits
    64.times |i|
    {
      mask := 0b1.shiftl(i)
      slot := "bit${i}"
      if (val == null) set(slot, null)
      else set(slot, StatusBool(val.and(mask) == mask, status))
    }

    // update bytes
    8.times |i|
    {
      slot := "byte${i}"
      if (val == null) set(slot, null)
      else set(slot, StatusNumber(Number(val.shiftr(i*8).and(0xFF)), status))
    }
  }
}

