//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Oct 2013  Brian Frank       Creation
//   14 Jan 2022  Matthew Giannini  Redesign for Haxall
//

using concurrent
using util
using haystack
using hx

**
** ModbusRegisterMap models a specific device's register
** mapping to/from normalized data.
**
const class ModbusRegMap
{

//////////////////////////////////////////////////////////////////////////
// Conn Mapping
//////////////////////////////////////////////////////////////////////////

  **
  ** Given a modbusConn rec, lookup its configured register map.
  ** There must be 'modbusRegMapUri' tag with a URI to the CSV file
  ** as "fan:" URI or path relative to the project directory.
  ** Raise an error if not configured correctly or CSV cannot be
  ** loaded.
  **
  static ModbusRegMap fromConn(HxRuntime rt, Dict rec)
  {
    uri := rec["modbusRegMapUri"] as Uri ?: throw FaultErr("Missing modbusRegMapUri tag")
    file := uriToFile(rt, uri)
    if (!file.exists) throw FaultErr("File not found for modbusRegMapUri: $uri")
    return fromFile(file)
  }

  internal static File uriToFile(HxRuntime rt, Uri uri)
  {
    if (uri.scheme == "fan") return uri.get
    if (!uri.isPathAbs) return rt.dir.plus(`$uri`)
    throw FaultErr("Unsupported modbusRegMapUri: $uri")
  }

//////////////////////////////////////////////////////////////////////////
// File
//////////////////////////////////////////////////////////////////////////

  **
  ** Read a file.  This method supports an internalized cache that
  ** only reloads the file if it has been modified.
  **
  static ModbusRegMap fromFile(File file)
  {
    /// check cache
    cached := ((Uri:ModbusRegMap)fileCache.val).get(file.uri)
    if (cached != null && cached.modified == file.modified) return cached

    // load it
    map := parseFile(file)

    // add to cache
    fileCache.val = ((Uri:ModbusRegMap)fileCache.val).dup.set(file.uri, map).toImmutable
    return map
  }

  private static const AtomicRef fileCache := AtomicRef(Uri:ModbusRegMap[:].toImmutable)

//////////////////////////////////////////////////////////////////////////
// Parse
//////////////////////////////////////////////////////////////////////////

  ** Parse from a CSV file
  private static ModbusRegMap parseFile(File file)
  {
    registers := ModbusReg[,]

    // parse as CSV
    rows := CsvInStream(file.in).readAllRows

    // map header columns
    headers := rows.first
    if (headers.isEmpty) throw IOErr("CSV file has no rows")
    colName  := csvColIndex(headers, "name")
    colAddr  := csvColIndex(headers, "addr")
    colData  := csvColIndex(headers, "data")
    colRw    := csvColIndex(headers, "rw")
    colScale := csvColIndex(headers, "scale", false)
    colDis   := csvColIndex(headers, "dis", false)
    colUnits := csvColIndex(headers, "unit", false)
    colTags  := csvColIndex(headers, "tags", false)

    rows.eachRange(1..-1) |row, i|
    {
      try
      {
        registers.add(ModbusReg
        {
          it.name = row[colName]
          it.addr = ModbusAddr(row[colAddr])
          it.data = ModbusData.fromStr(row[colData])
          it.readable = row[colRw].contains("r")
          it.writable = row[colRw].contains("w")
          if (colScale >= 0) it.scale = ModbusScale(row[colScale], false)
          if (colDis   >= 0) it.dis   = row[colDis]
          if (colUnits >= 0) it.unit  = Unit(row[colUnits], false)
          if (colTags  >= 0) it.tags  = ZincReader(row[colTags].in).readTags
        })
      }
      catch (Err e)
      {
        throw IOErr("Invalid register row [line ${i+1}]", e)
      }
    }

    return make(file, registers)
  }

  private static Int csvColIndex(Str[] row, Str name, Bool checked := true)
  {
    index := row.findIndex |cell| { cell == name }
    if (index != null) return index
    if (checked) throw IOErr("CSV missing required column $name.toCode")
    return -1
  }

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Private constructor
  private new make(File file, ModbusReg[] regs)
  {
    this.file     = file
    this.modified = file.modified
    this.regs     = regs
    this.byName   = Str:ModbusReg[:].addList(regs) |r| { r.name }
  }

//////////////////////////////////////////////////////////////////////////
// Registers
//////////////////////////////////////////////////////////////////////////

  ** List of all the registers in this map
  const ModbusReg[] regs

  ** Lookup a register by its name
  ModbusReg? reg(Str name, Bool checked := true)
  {
    reg := byName[name]
    if (reg != null) return reg
    if (checked) throw UnknownNameErr("ModbusReg: $name")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const File file
  private const DateTime modified
  private const Str:ModbusReg byName
}
