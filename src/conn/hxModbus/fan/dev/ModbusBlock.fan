//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Feb 2017  Andy Frank       Creation
//  14 Jan 2022  Matthew Giannini Redesign for Haxall
//

using concurrent
using haystack

**
** ModbusBlock models a list of registers that can be read
** in single block read.
**
@NoDoc const class ModbusBlock
{
  **
  ** Optimize a list of registers into a list of blocks that
  ** can be efficiently read from a device using block reads.
  ** Resulting block lists can be tuned with:
  **
  **  - gap: max number gaps inside a block
  **  - max: max number of registers for one block (including gaps)
  **
  static ModbusBlock[] optimize(ModbusReg[] regs, Int gap := 0, Int max := 100)
  {
    if (gap < 0) throw ArgErr("Invalid gap: $gap (must be >= 0)")
    if (max < 1) throw ArgErr("Invalid max: $max (must be >= 1)")

    blocks := ModbusBlock[,]
    acc    := ModbusReg[,]

    regs = regs.sort |a,b| { a.addr.qnum <=> b.addr.qnum }
    regs.each |r|
    {
      if (acc.isEmpty) acc.add(r)
      else
      {
        first := acc.first.addr.qnum
        cur   := r.addr.qnum
        curt  := r.addr.type
        last  := acc.last.addr.qnum + acc.last.data.size
        lastt := acc.last.addr.type
        if (curt != lastt || cur-last > gap || cur-first >= max)
        {
          blocks.add(ModbusBlock(acc))
          acc.clear
        }
        acc.add(r)
      }
    }
    if (acc.size > 0) blocks.add(ModbusBlock(acc))
    return blocks
  }

  ** It-block ctor.
  new make(ModbusReg[] regs)
  {
    if (regs.size == 0)
    {
      this.type = ModbusAddrType.holdingReg
      this.regs = regs
    }
    else
    {
// TODO: think we need to inject scale refs here...
      this.type = regs.first.addr.type
      if (regs.any |r| { type != r.addr.type }) throw ArgErr("Addr types do not match")
      this.regs = regs.sort |a,b| { a.addr.num <=> b.addr.num }
    }
  }

  ** Type for this block.
  const ModbusAddrType type

  ** Continuous or semi-continuous block of registers.
  const ModbusReg[] regs

  ** Start address of first register in this block.
  Int start() { regs.first.addr.num }

  ** Number of 16-bit Modbus registers required to be read for this block.
  Int size()
  {
    if (regs.size == 0) return 0
    if (regs.size == 1) return regs.first.data.size
    return (regs.last.addr.num + regs.last.data.size) - start
  }

  ** Block values for each register. Throws Err
  ** if this block has not yet been resolved.
  Obj[] vals() { valsRef.val ?: throw Err("Block not resolved") }
  private const AtomicRef valsRef := AtomicRef(null)

  ** Resolve this block with given raw registers results.
  internal Void resolve(Obj[] raw)
  {
    if (type.isBool)
    {
      this.valsRef.val = raw.toImmutable
      return
    }
    else
    {
      vals := Obj[,]
      regs.each |r|
      {
        try
        {
          off   := r.addr.num - start
          slice := raw[off..<(off+r.data.size)]
          num   := r.data.fromRegs(slice, r.unit)
          sf    := r.scale?.factor
          if (sf != null) num = r.scale.compute(num, sf)
          vals.add(num)
        }
        catch (Err err) { vals.add(err) }
      }
      this.valsRef.val = vals.toImmutable
    }
  }

  ** Mark this block resovled with error condition.
  internal Void resolveErr(Err err)
  {
    vals := [,]
    regs.each |r,i| { vals.add(err) }
    this.valsRef.val = vals.toImmutable
  }
}