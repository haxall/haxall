//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Apr 2010  Brian Frank  Creation
//    1 Feb 2022  Brian Frank  Redesign for Haxall
//

using haystack
using concurrent
using hx

**
** SqlTest
**
class SqlConnTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Setup
//////////////////////////////////////////////////////////////////////////

  ** Setup and return connector based on etc/sql/config.props
  Dict? sqlTestInit()
  {
    addLib("sql")

    // configure one
    sqlPod := Pod.find("sql")
    conn := addRec([
            "dis":      "Test SQL Conn",
            "sqlConn":  Marker.val,
            "uri":      sqlPod.config("test.uri").toUri,
            "username": sqlPod.config("test.username"),
            "sqlSyncHisExpr": "testSyncHis"])

    rt.db.passwords.set(conn.id.toStr, sqlPod.config("test.password"))

    grid := (Grid)eval("read(sqlConn).sqlTables()")
    verifyEq(grid.cols[0].name, "name")
    grid = eval("sqlTables($conn.id.toCode)")
    verifyEq(grid.cols[0].name, "name")

    rt.sync

    return conn
  }

//////////////////////////////////////////////////////////////////////////
// Basics
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testBasics()
  {
    // setup (with basic pre/post setup checks)
    conn := sqlTestInit

    // drop test table
    try eval("""read(sqlConn).sqlExecute("drop table sqlext_test_basics")"""); catch (Err e) {}

    // create fresh test table
    x := eval(
    """read(sqlConn).sqlExecute(
        "create table sqlext_test_basics(
         tid int auto_increment not null,
         dis varchar(255) not null,
         date date,
         dur varchar(255) not null,
         num int,
         primary key (tid))"
         )""".replace("\n", " "))
    grid := (Grid)eval("read(sqlConn).sqlTables()")
    verifyEq(grid.findAll |row| { row->name == "sqlext_test_basics" }.size, 1)

    // insert single dict
    // TODO: using Date with mysql has off-by-one days, but using string works
    aId := eval("""sqlInsert({dis:"Alpha", date:"2010-04-20", dur:"forever", num:66m}, read(sqlConn), "sqlext_test_basics")""")
    verify(aId is Number)
    grid = eval("""sqlQuery($conn.id.toCode, "select * from sqlext_test_basics")""")
    verifyEq(grid.size, 1)
    verifyDictEq(grid[0], ["tid": aId, "dis":"Alpha", "date":Date("2010-04-20"), "dur":"forever", "num":n(66)])

    // add some recs with same tags
    addRec(["foo":Marker.val, "dis":"Beta",  "date":Date(2010, Month.jun, 7).toStr, "dur":n(1, "min")])
    addRec(["foo":Marker.val, "dis":"Gamma", "date":Date(2011, Month.jun, 7).toStr, "dur":n(5, "min")])
    Obj[] ids := eval("""readAll(foo).sort("date").sqlInsert($conn.id.toCode, "sqlext_test_basics")""")
    grid = eval("""read(sqlConn).sqlQuery("select * from sqlext_test_basics").sort("date")""")
    verifyEq(grid.size, 3)
    verifyDictEq(grid[0], ["tid": aId,    "dis":"Alpha", "date":Date(2010, Month.apr, 20), "dur":"forever", "num":n(66)])
    verifyDictEq(grid[1], ["tid": ids[0], "dis":"Beta",  "date":Date(2010, Month.jun, 7),  "dur":"1min"])
    verifyDictEq(grid[2], ["tid": ids[1], "dis":"Gamma", "date":Date(2011, Month.jun, 7),  "dur":"5min"])

    // get meta-data
    grid = eval(Str<|read(sqlConn).sqlQuery("select dis as \"Dis-Name\" from sqlext_test_basics").sort("dis_Name")|>)
    verifyEq(grid.cols.size, 1)
    verifyEq(grid.cols.first.name, "dis_Name") // Etc.toTagName
    verifyEq(grid.cols.first.meta["sqlName"], "Dis-Name") // actual SQL name

    // verify executes
    r := eval("""sqlExecute($conn.id.toCode, "update sqlext_test_basics set num=987 where dis=\\"Alpha\\"")""")
    verifyEq(r, n(1))
    grid = eval("""sqlExecute($conn.id.toCode, "select * from sqlext_test_basics").sort("dis")""")
    verifyEq(grid.size, 3)
    verifyEq(grid[0]->dis, "Alpha")
    verifyEq(grid[1]->dis, "Beta")
    verifyEq(grid[2]->dis, "Gamma")
  }

//////////////////////////////////////////////////////////////////////////
// Sync His
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testSyncHis()
  {
    conn := sqlTestInit

    // create out function
    addFuncRec("testSyncHis",
      """(conn, his, range) => do
            //echo("sync " + conn->dis  +"," + his.toDis + ", " + range)
            sql: "select timestamp, value from " + his->tableName +
                 " where timestamp >= '" + range.start.format("YYYY-MM-DD hh:mm:ss") + "'" +
                 " and   timestamp <= '" + range.end.format("YYYY-MM-DD hh:mm:ss") + "'"
            //echo(sql)
            sqlQuery(conn, sql)
         end""")

    // drop test tables
    try eval("""sqlExecute($conn.id.toCode, "drop table sqlext_test_sync_his_a")"""); catch (Err e) {}

    // create SQL table of history (one table per history model)
    x := eval(
    """read(sqlConn).sqlExecute(
        "create table sqlext_test_sync_his_a(
         timestamp datetime,
         value float)"
         )""".replace("\n", " "))

    // create skyspark side history
    hisA := addRec(["his":m, "tz":"New_York",
      "dis":"His-A", "sqlConnRef":conn.id,
      "kind":"Number", "point":m,
      "tableName":"sqlext_test_sync_his_a"])
    sync(conn)

    // test empty sync
    eval("sqlSyncHis($hisA.id.toCode)")
    sync(conn)
    hisA = readById(hisA.id)
    verifySyncStatus(hisA, 0)

    // add some data to sql table
    eval(
    """sqlInsert(
         [{timestamp: dateTime(2010-04-25, 1:00, "New_York"), value: 2501},
          {timestamp: dateTime(2010-04-25, 5:00, "New_York"), value: 2505},
          {timestamp: dateTime(2010-04-26, 3:00, "New_York"), value: 2603},
          {timestamp: dateTime(2010-04-26, 4:00, "New_York"), value: 2604}],
          ${conn.id.toCode},
          "sqlext_test_sync_his_a")""")
    // evalToGrid("""sqlQuery("select * from sqlext_test_sync_his_a")""").dump

    // test empty sync for just 2010-04-25
    tz := TimeZone("New_York")
    eval("sqlSyncHis($hisA.id.toCode, 2010-04-25)")
    sync(conn)
    hisA = readById(hisA.id)
    verifySyncStatus(hisA, 2)
    sync(conn)
    h := (Grid)eval("hisRead($hisA.id.toCode, null)")
    verifyRows(h,
      [[dt(2010, 4, 25, 1, 0, tz), n(2501)],
       [dt(2010, 4, 25, 5, 0, tz), n(2505)]])

    // sync end
    r := eval("sqlSyncHis($hisA.id.toCode)")
    sync(conn)
    s := ZincWriter.gridToStr(Etc.toGrid(r))  // sanity check
    hisA = readById(hisA.id)
    verifySyncStatus(hisA, 2)
    sync(conn)
    h = eval("hisRead($hisA.id.toCode, null)")
    verifyRows(h,
      [[dt(2010, 4, 25, 1, 0, tz), n(2501)],
       [dt(2010, 4, 25, 5, 0, tz), n(2505)],
       [dt(2010, 4, 26, 3, 0, tz), n(2603)],
       [dt(2010, 4, 26, 4, 0, tz), n(2604)]])

    // sync again just to make sure empty sync is ok
    r = eval("sqlSyncHis($hisA.id.toCode)")
    sync(conn)
    s = ZincWriter.gridToStr(Etc.toGrid(r))  // sanity check
    hisA = readById(hisA.id)
    verifySyncStatus(hisA, 0)
  }

  Dict addFuncRec(Str name, Str src, Str:Obj? tags := Str:Obj?[:])
  {
    tags["def"] = Symbol("func:$name")
    tags["src"]  = src
    r := addRec(tags)
    rt.sync
    return r
  }


  Void verifyRows(Grid g, Obj?[][] expected)
  {
    verifyEq(g.size, expected.size)
    i := 0
    g.each |row|
    {
      e := expected[i++]
      verifyEq(row->ts,  e[0])
      verifyEq(row->val, e[1])
    }
    verifyEq(i, expected.size)
  }

  Void verifySyncStatus(Dict rec, Int count)
  {
    verifyEq(rec["hisStatus"], "ok")
    verifyEq(rec["hisErr"], null)
  }

  Void sync(Dict conn)
  {
    rt.sync
  }

  static DateTime dt(Int y, Int m, Int d, Int h, Int min, TimeZone tz := TimeZone.utc)
  {
    DateTime(y, Month.vals[m-1], d, h, min, 0, 0, tz)
  }
}