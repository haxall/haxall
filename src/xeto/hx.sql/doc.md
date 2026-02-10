<!--
title:      SqlExt
author:     Brian Frank
created:    14 Jun 2010
copyright:  Copyright (c) 2010, SkyFoundry LLC
license:    Licensed under the AFL v3.0
-->

# Overview
The SQL connector is used to integrate with relational database using JDBC.
It follows the standard connector model:
  - [Connectors](#connectors): used to configure a JDBC connection to
    a database server
  - [Functions](#funcs): provide access read/write for Axon scripts
  - [His Sync](#his-sync): framework for scheduling synchronization
    of external RDBMS data with the historian

# Setup
The SQL connector leverages the Fantom and Java JDBC infrastructure
for connecting to databases.  For setup:

1. Ensure your JDBC driver is installed and available via
the system class path.  The best place to stick it is in
the **{home}/lib/java/ext** directory.

2. Ensure the JDBC class is loaded into memory.  The simplest way
to preload the class is to ensure the classname is defined in
**{home}/etc/sql/config.props**:

        java.drivers=com.microsoft.sqlserver.jdbc.SQLServerDriver

If using Microsoft SQL Server:
  a. Assuming you are running Java 1.8 or higher, then make sure you put only
     "sqljdbc4.jar" into your classpath (do **not** put "sqljdbc.jar" in the path)
  b. Classname is "com.microsoft.sqlserver.jdbc.SQLServerDriver" (for java.drivers
     in etc/sql/config.props)
  c. JDBC URL format is "jdbc:sqlserver://{host};database={name}"

# Connectors
Each database you communicate with needs to have a sqlConn record
defined with the following tags:
  - [hx.conn::Conn.conn]: required marker tag
  - [SqlConn.sqlConn]: required marker tag
  - [SqlConn.uri]: JDBC URI such as "jdbc:mysql://localhost:3306/mytestdb"; review
    database  JDBC documentation to verify the format of the JDBC URI
  - [hx::User.username]: username to use for database login
  - [SqlConn.password]: must have password stored in [password db](fan.folio::PasswordStore)
    for connector's record id
  - [SqlConn.sqlSyncHisExpr]: this tag is required if using the [connSyncHis()]
    function which is discussed later

You can test our your connector using the [connPing()] function:

    read(sqlConn).connPing

If the ping is successful it will update your connector record
with tags indicating version of the database and JDBC driver.

# Funcs
There are four Axon basic functions for working with a SQL database:
  - [sqlTables()]: query tables defined
  - [sqlQuery()]: run "select" query and return grid
  - [sqlExecute()]: run modification command such as "create", "drop", etc
  - [sqlInsert()]: export data to a SQL table

Some examples for using a SQL connector:

    // read list of tables
    read(sqlConn).sqlTables

    // read tables using connector id
    sqlTables(sqlConnId)

    // simple query
    read(sqlConn).sqlQuery("select * from some_table")

    // simple execute
    read(sqlConn).sqlExecute("drop table old_table")

    // insert sites into SQL table
    readAll(site).sqlInsert(sqlConnId, "site_table")

    // insert list of dict literals
    data: [{first_name:"Alice", last_name:"Rock"},
           {first_name:"Bob",   last_name:"Smith"}]
    sqlInsert(data, sqlConnId, "people_table")

# His Sync
The SQL extension follows the standard [connSyncHis()] design used by other
connectors except you must provide the implementation.  You configure SQL
proxy points as normal [his-points](ph::HisPoint) along with the [SqlPoint.sqlConnRef] tag.

Each sqlConn must define the [SqlConn.sqlSyncHisExpr] tag which evaluates to an
Axon function that takes the syncConn, his, and span.  This function is
responsible for performing a SQL query to get the data into the correct
format used to write into the historian.

For a simple example let's assume that each history is defined in its own
unique table, here is a strategy:
  1. Add a `tableName` tag to each of the proxy histories
  2. Create "sqlSyncFromTable" function (shown below)
  3. Set `sqlSyncHisExpr: "sqlSyncFromTable"` in the sqlConn

Here is example code for "sqlSyncFromTable":

    (conn, his, range) => do
       sql: "select timestamp, value from " + his->tableName +
            " where timestamp >= '" + range.start.format("YYYY-MM-DD hh:mm:ss") + "'" +
            " and   timestamp <= '" + range.end.format("YYYY-MM-DD hh:mm:ss") + "'"
       sqlQuery(conn, sql)
     end

Note: The system requires the your timestamps to be the correct timezones of the
target histories.  Since SQL databases tend to have very weak timezone support
you will want to test this thoroughly, especially if your projects span multiple
timezones.

Once everything is setup, you can use [hx.conn::Funcs.connSyncHis] to synchronize one or
more histories with the SQL connector:

    connSyncHis(points, pastWeek)

