//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Apr 2010  Brian Frank  Creation
//   22 Jun 2021  Brian Frank  Redesign for Haxall
//

using concurrent
using sql::Col as SqlCol
using sql::Row as SqlRow
using haystack
using axon
using hx
using hxConn

**
** SQL connector functions
**
const class SqlFuncs
{
  ** Deprecated - use `connPing()`
  @Deprecated @Axon { admin = true }
  static Future sqlPing(Obj conn)
  {
    ConnFwFuncs.connPing(conn)
  }

  ** Deprecated - use `connSyncHis()`
  @Deprecated @Axon { admin = true }
  static Obj? sqlSyncHis(Obj points, Obj? span := null)
  {
    ConnFwFuncs.connSyncHis(points, span)
  }

  ** Return plain text report on JDBC drivers installed.
  @Axon { admin = true }
  static Str sqlDebugDrivers()
  {
    sql::SqlConnImpl.debugDrivers
  }

  **
  ** Query the tables defined for the database.
  ** Return a grid with the 'name' column.
  **
  ** Examples:
  **   read(sqlConn).sqlTables
  **   sqlTables(sqlConnId)
  **
  @Axon { admin = true }
  static Grid sqlTables(Obj conn)
  {
    withConn(conn) |db|
    {
      gb := GridBuilder().addCol("name")
      tables := db.meta.tables
      tables.each |table| { gb.addRow1(table) }
      return gb.toGrid
    }
  }

  **
  ** Execute a SQL query and return the result as a grid.
  ** Blob columns under 10K are returned as base64.
  **
  ** Examples:
  **   read(sqlConn).sqlQuery("select * from some_table")
  **   sqlQuery(sqlConnId, "select * from some_table")
  **
  ** WARNING: any admin user will have full access to query the
  ** database based on the user account configured by the sqlConn.
  **
  @Axon { admin = true }
  static Grid sqlQuery(Obj conn, Str sql)
  {
    withConn(conn) |db|
    {
      return rowsToGrid(db.sql(sql).query)
    }
  }

  **
  ** Execute a SQL statement and if applicable return a result.
  ** If the statement produced auto-generated keys, then return
  ** an list of the keys generated, otherwise return number of
  ** rows modified.
  **
  ** WARNING: any admin user will have full access to update the
  ** database based on the user account configured by the sqlConn.
  **
  @Axon { admin = true }
  static Obj? sqlExecute(Obj conn, Str sql)
  {
    withConn(conn) |db|
    {
      return fromSqlVal(db.sql(sql).execute)
    }
  }

  **
  ** Insert a record or grid of records into the given table.
  ** If data is a dict, thena single row is inserted.  If data
  ** is a grid or list of dicts, then each row is inserted.  The data's
  ** column names must match the table's columns.  If the data has a
  ** tag/column not found in the table then it is ignored.
  **
  ** WARNING: any admin user will have full access to update the
  ** database based on the user account configured by the sqlConn.
  **
  @Axon { admin = true }
  static Obj? sqlInsert(Obj? data, Obj conn, Str table)
  {
    withConn(conn) |db|
    {
      // get table definition
      tr := db.meta.tableRow(table)

      // if single row, turn into grid
      single := false
      Grid? input
      if (data is Dict) { single = true; input = Etc.makeDictGrid(null, data) }
      else input = Etc.toGrid(data)

      // build prepared statement based on intersection of table
      // and grid columns
      s1 := StrBuf().add("insert into ").add(table).add(" (")
      s2 := StrBuf().add(" values (")
      inputCols := SqlCol[,]
      tr.cols.each |tcol|
      {
        name := tcol.name
        if (name == "id") return // never process id, just asking for trouble
        if (input.missing(name)) return
        inputCols.add(tcol)
        s1.add(name).add(",")
        s2.add("@").add(name).add(",")
      }
      s1[-1] = ')'; s2[-1] = ')'
      sqlStr := s1.add(s2).toStr
      stmt := db.sql(sqlStr).prepare

      // now insert each input row
      // TODO: this isn't very efficient, need to batch
      results := Obj[,]
      input.each |inputRow|
      {
        params := Str:Obj?[:]
        inputCols.each |inputCol|
        {
          name := inputCol.name
          params[name] = toSqlVal(inputRow.trap(name, null), inputCol)
        }

        // execute with params and store result
        r := stmt.execute(params)
        if (r is List) r = ((List)r)[0]
        results.add(fromSqlVal(r))
      }

      // return results
      if (single) return fromSqlVal(results.first)
      return results
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static Obj? withConn(Obj conn, |sql::SqlConn->Obj?| f)
  {
    conn = curContext.rt.conn.conn(Etc.toId(conn))
    db := SqlLib.doOpen(conn)
    try
      return f(db)
    finally
      db.close
  }

  private static Obj? fromSqlVal(Obj? val)
  {
    if (val is Num) return Number.makeNum(val)
    if (val is Buf)
    {
      buf := (Buf)val
      if (buf.size <= 10240) return buf.toBase64
      return "Blob size=$buf.size"
    }
    if (val is List)
    {
      list := (List)val
      if (list.of == Int#) return list.map |x->Number| { Number.makeInt(x) }
      if (list.of == Str#) return list
      if (list.of == SqlRow#) return rowsToGrid(list)
      throw Err("Unsupported SQL list type: $list.typeof")
    }
    return val
  }

  private static Grid rowsToGrid(SqlRow[] result)
  {
    if (result.isEmpty) return Etc.makeEmptyGrid

    // map columns
    cols := Str[,]
    colMetas := Dict[,]
    result.first.cols.each |col|
    {
      cols.add(Etc.toTagName(col.name))
      colMetas.add(Etc.makeDict(["sqlName": col.name]))
    }

    // map rows
    rows := Obj[,]
    result.each |r|
    {
      row := Obj?[,]
      r.cols.each |col| { row.add(fromSqlVal(r[col])) }
      rows.add(row)
    }
    return Etc.makeListsGrid(null, cols, colMetas, rows)
  }

  private static Obj? toSqlVal(Obj? val, SqlCol col)
  {
    if (col.type == Str#) return val == null ? "null" : val.toStr
    if (val is Number)
    {
      if (col.type == Float#) return ((Number)val).toFloat
      if (col.type == Int#) return ((Number)val).toInt
    }
    return val
  }

  private static HxContext curContext() { HxContext.curHx }
}