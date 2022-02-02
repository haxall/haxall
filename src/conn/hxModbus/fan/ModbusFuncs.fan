//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jul 2012  Andy Frank         Creation
//  12 Jan 2022  Matthew Giannini   Redesign for Haxall
//

using concurrent
using util
using haystack
using axon
using hx
using hxConn

**
** Modbus connector functions
**
const class ModbusFuncs
{
  ** Utility to get the current HxContext
  private static HxContext cx() { HxContext.curHx }

  ** Deprecated - use `connPing()`
  @Deprecated @Axon { admin = true }
  static Future modbusPing(Obj conn)
  {
    ConnFwFuncs.connPing(conn)
  }

  ** Deprecated - use `connLearn()`
  @Deprecated @Axon { admin = true }
  static Grid modbusLearn(Obj conn, Obj? arg := null)
  {
    ConnFwFuncs.connLearn(conn, arg).get(1min)
  }

  ** Deprecated - use `connSyncCur()`
  @Deprecated @Axon { admin = true }
  static Obj? modbusSyncCur(Obj points)
  {
    ConnFwFuncs.connSyncCur(points)
  }

  **
  ** Read a point value for given register name on connector instance.
  ** The 'regs' argument may be a single 'Str' name, or a 'Str[]' for a
  ** block read. The grid returned will contain a row for each register
  ** requested and two columns: 'name' and 'val'.
  **
  @Axon { admin = true }
  static Grid modbusRead(Obj conn, Obj regs)
  {
    list := regs as Str[] ?: Str[regs]
    return ModbusLib.cur.read(conn, list)
  }

  **
  ** Write a value to given register name on connecter instance.
  **
  @Axon { admin = true }
  static Void modbusWrite(Obj conn, Str reg, Obj val)
  {
    ModbusLib.cur.write(conn, reg, val)
  }


  ** Return given register map contents. Do not include the file extension in the name.
  **
  **  modbusRegMap("myRegisterMap")
  @Axon
  static Grid modbusRegMap(Str name)
  {
    f := regMapDir(cx) + `${name}.csv`

    // trap exists so we don't leak path info
    if (!f.exists) throw IOErr("Register map not found: ${name}")

    in := CsvInStream(f.in)
    gb := GridBuilder()
    gb.addColNames(in.readRow)
    in.eachRow |r| { gb.addRow(r) }
    in.close
    return gb.toGrid
  }

  ** List installed register maps including source.
  @Axon
  static Grid modbusRegMaps()
  {
    gb := GridBuilder()
    gb.addColNames(["name", "uri", "src"])

    // {proj}/data/modbus/
    regMapDir(cx).listFiles.each |f|
    {
      if (f.ext != "csv") return
      uri := f.uri.relTo(cx.rt.dir.uri)
      gb.addRow([f.basename, uri, f.readAllStr])
    }

    return gb.toGrid.sort |a,b|
    {
      a->name.toStr.localeCompare(b->name.toStr)
    }
  }

//////////////////////////////////////////////////////////////////////////
// RegMapEditor
//////////////////////////////////////////////////////////////////////////

  ** List installed register maps.
  @NoDoc @Axon { admin = true }
  static Grid modbusRegMapList() { modbusRegMaps() }
  /* OLD IMPLEMENTATION - looks like maybe it was going to try and do something with templates
   * Leaving for reference
  {
    gb := GridBuilder()
    gb.addColNames(["name", "uri", "src"])

    // {proj}/data/modbus
    regMapDir(cx).listFiles.each |f|
    {
      if (f.ext != "csv") return
      uri := f.uri.relTo(cx.dir.uri)
      gb.addRow([f.basename, uri, f.readAllStr])
    }

    // templates marked modbus with regmap.csv file
    /* TODO-3
    templates := SysEnv.cur.templates.findAll |t| { t.meta.has("modbus") }
    templates.each |t|
    {
      f := t.dir.find |x| { x.name == "regmap.csv" }
      if (f != null) gb.addRow([t.meta.dis, f.uri, f.readAllStr])
    }
    */

    return gb.toGrid.sort |a,b| { a->name.toStr.localeCompare(b->name.toStr) }
  }
  */

  ** Save a regiser map.
  @NoDoc @Axon { admin = true }
  static Void modbusRegMapSave(Str name, Str src)
  {
    file := regMapDir(cx) + `${name}.csv`
    file.out.print(src).flush.close
  }

  ** Rename a register map.
  @NoDoc @Axon { admin = true }
  static Void modbusRegMapMove(Str oldName, Str newName)
  {
    file := regMapDir(cx) + `${oldName}.csv`
    file.rename("${newName}.csv")
  }

  ** Delete a register map.
  @NoDoc @Axon { admin = true }
  static Void modbusRegMapDelete(Obj names)
  {
    list := names as Str[] ?: [names.toStr]
    list.each |name|
    {
      file := regMapDir(cx) + `${name}.csv`
      if (file.exists) file.delete
    }
  }

  ** Get the register map storage directory
  private static File regMapDir(HxContext cx)
  {
    dir := cx.rt.dir + `data/modbus/`
    if (!dir.exists) dir.create
    return dir
  }
}