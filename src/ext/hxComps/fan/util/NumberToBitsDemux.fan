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
class NumberToBitsDemux : HxComp
{
  /* ionc-start */

  ** The input number
  virtual StatusNumber? in() { get("in") }

  ** Bit 0
  virtual StatusBool? bit0() { get("bit0") }

  ** Bit 1
  virtual StatusBool? bit1() { get("bit1") }

  ** Bit 2
  virtual StatusBool? bit2() { get("bit2") }

  ** Bit 3
  virtual StatusBool? bit3() { get("bit3") }

  ** Bit 4
  virtual StatusBool? bit4() { get("bit4") }

  ** Bit 5
  virtual StatusBool? bit5() { get("bit5") }

  ** Bit 6
  virtual StatusBool? bit6() { get("bit6") }

  ** Bit 7
  virtual StatusBool? bit7() { get("bit7") }

  ** Bit 8
  virtual StatusBool? bit8() { get("bit8") }

  ** Bit 9
  virtual StatusBool? bit9() { get("bit9") }

  ** Bit 10
  virtual StatusBool? bit10() { get("bit10") }

  ** Bit 11
  virtual StatusBool? bit11() { get("bit11") }

  ** Bit 12
  virtual StatusBool? bit12() { get("bit12") }

  ** Bit 13
  virtual StatusBool? bit13() { get("bit13") }

  ** Bit 14
  virtual StatusBool? bit14() { get("bit14") }

  ** Bit 15
  virtual StatusBool? bit15() { get("bit15") }

  ** Bit 16
  virtual StatusBool? bit16() { get("bit16") }

  ** Bit 17
  virtual StatusBool? bit17() { get("bit17") }

  ** Bit 18
  virtual StatusBool? bit18() { get("bit18") }

  ** Bit 19
  virtual StatusBool? bit19() { get("bit19") }

  ** Bit 20
  virtual StatusBool? bit20() { get("bit20") }

  ** Bit 21
  virtual StatusBool? bit21() { get("bit21") }

  ** Bit 22
  virtual StatusBool? bit22() { get("bit22") }

  ** Bit 23
  virtual StatusBool? bit23() { get("bit23") }

  ** Bit 24
  virtual StatusBool? bit24() { get("bit24") }

  ** Bit 25
  virtual StatusBool? bit25() { get("bit25") }

  ** Bit 26
  virtual StatusBool? bit26() { get("bit26") }

  ** Bit 27
  virtual StatusBool? bit27() { get("bit27") }

  ** Bit 28
  virtual StatusBool? bit28() { get("bit28") }

  ** Bit 29
  virtual StatusBool? bit29() { get("bit29") }

  ** Bit 30
  virtual StatusBool? bit30() { get("bit30") }

  ** Bit 31
  virtual StatusBool? bit31() { get("bit31") }

  ** Bit 32
  virtual StatusBool? bit32() { get("bit32") }

  ** Bit 33
  virtual StatusBool? bit33() { get("bit33") }

  ** Bit 34
  virtual StatusBool? bit34() { get("bit34") }

  ** Bit 35
  virtual StatusBool? bit35() { get("bit35") }

  ** Bit 36
  virtual StatusBool? bit36() { get("bit36") }

  ** Bit 37
  virtual StatusBool? bit37() { get("bit37") }

  ** Bit 38
  virtual StatusBool? bit38() { get("bit38") }

  ** Bit 39
  virtual StatusBool? bit39() { get("bit39") }

  ** Bit 40
  virtual StatusBool? bit40() { get("bit40") }

  ** Bit 41
  virtual StatusBool? bit41() { get("bit41") }

  ** Bit 42
  virtual StatusBool? bit42() { get("bit42") }

  ** Bit 43
  virtual StatusBool? bit43() { get("bit43") }

  ** Bit 44
  virtual StatusBool? bit44() { get("bit44") }

  ** Bit 45
  virtual StatusBool? bit45() { get("bit45") }

  ** Bit 46
  virtual StatusBool? bit46() { get("bit46") }

  ** Bit 47
  virtual StatusBool? bit47() { get("bit47") }

  ** Bit 48
  virtual StatusBool? bit48() { get("bit48") }

  ** Bit 49
  virtual StatusBool? bit49() { get("bit49") }

  ** Bit 50
  virtual StatusBool? bit50() { get("bit50") }

  ** Bit 51
  virtual StatusBool? bit51() { get("bit51") }

  ** Bit 52
  virtual StatusBool? bit52() { get("bit52") }

  ** Bit 53
  virtual StatusBool? bit53() { get("bit53") }

  ** Bit 54
  virtual StatusBool? bit54() { get("bit54") }

  ** Bit 55
  virtual StatusBool? bit55() { get("bit55") }

  ** Bit 56
  virtual StatusBool? bit56() { get("bit56") }

  ** Bit 57
  virtual StatusBool? bit57() { get("bit57") }

  ** Bit 58
  virtual StatusBool? bit58() { get("bit58") }

  ** Bit 59
  virtual StatusBool? bit59() { get("bit59") }

  ** Bit 60
  virtual StatusBool? bit60() { get("bit60") }

  ** Bit 61
  virtual StatusBool? bit61() { get("bit61") }

  ** Bit 62
  virtual StatusBool? bit62() { get("bit62") }

  ** Bit 63
  virtual StatusBool? bit63() { get("bit63") }

  ** Byte 0
  virtual StatusNumber? byte0() { get("byte0") }

  ** Byte 1
  virtual StatusNumber? byte1() { get("byte1") }

  ** Byte 2
  virtual StatusNumber? byte2() { get("byte2") }

  ** Byte 3
  virtual StatusNumber? byte3() { get("byte3") }

  ** Byte 4
  virtual StatusNumber? byte4() { get("byte4") }

  ** Byte 5
  virtual StatusNumber? byte5() { get("byte5") }

  ** Byte 6
  virtual StatusNumber? byte6() { get("byte6") }

  ** Byte 7
  virtual StatusNumber? byte7() { get("byte7") }

  /* ionc-end */

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

