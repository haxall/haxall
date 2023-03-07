//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jan 2023  Brian Frank  Creation
//

using data
using haystack
using axon

**
** Shell virtual database
**
internal class ShellDb
{

  Dict? readById(Ref id, Bool checked)
  {
    checkLoaded
    rec := byId[id]
    if (rec != null) return rec
    if (checked) throw UnknownRecErr(id.toZinc)
    return null
  }

  Grid readByIds(Ref[] ids, Bool checked)
  {
    recs := ids.map |id->Dict?| { readById(id, checked) }
    return toGrid(recs)
  }

  Dict? read(Filter filter, Bool checked, ShellContext cx)
  {
    checkLoaded
    rec := byId.find |rec| { filter.matches(rec, cx) }
    if (rec != null) return rec
    if (checked) throw UnknownRecErr(filter.toStr)
    return null
  }

  Dict[] readAllList(Filter filter, Dict opts, ShellContext cx)
  {
    checkLoaded
    acc := Dict[,]
    limit := (opts["limit"] as Number)?.toInt ?: Int.maxVal
    byId.eachWhile |rec|
    {
      if (filter.matches(rec, cx)) acc.add(rec)
      return acc.size < limit ? null : "break"
    }
    if (opts.has("sort")) Etc.sortDictsByDis(acc)
    return acc
  }

  Grid readAll(Filter filter, Dict opts, ShellContext cx)
  {
    toGrid(readAllList(filter, opts, cx))
  }

  Int readCount(Filter filter, ShellContext cx)
  {
    checkLoaded
    count := 0
    byId.each |rec| { if (filter.matches(rec, cx)) ++count }
    return count
  }

  Grid toGrid(Dict[] recs)
  {
    // build grid with most important columns first to fit in terminal
    cols := Etc.dictsNames(recs)
    cols.moveTo("id", 0)
    cols.moveTo("dis", 1)
    gb := GridBuilder()
    gb.addColNames(cols)
    return gb.addDictRows(recs).toGrid
  }

  Void load(Obj arg, ShellContext cx)
  {
    uri := arg as Uri ?: throw ArgErr("Load file must be Uri, not $arg.typeof")
    file := File(uri)

    echo("LOAD: loading '$file.osPath' ...")
    grid := readFile(file)

    // map grid into byId table
    byId.clear
    grid.each |rec|
    {
      id := rec["id"] as Ref
      if (id == null)
      {
        id = Ref.gen
        rec = Etc.dictSet(rec, "id", id)
      }
      byId.add(id, rec)
    }

    // map ids to their dis
    byId.each |rec|
    {
      rec.each |v, n| { if (v is Ref) mapRefDis(v) }
    }
    loaded = true

    echo("LOAD: loaded $byId.size recs")
  }

  private Void mapRefDis(Ref ref)
  {
    rec := byId[ref]
    if (rec == null) return
    ref.disVal = rec["dis"]
  }

  private Grid readFile(File file)
  {
    switch (file.ext)
    {
      case "zinc": return ZincReader(file.in).readGrid
      case "json": return JsonReader(file.in).readGrid
      case "trio": return TrioReader(file.in).readGrid
      case "csv":  return CsvReader(file.in).readGrid
      default:     throw ArgErr("ERROR: unknown file type [$file.osPath]")
    }
  }

  Void checkLoaded()
  {
    if (!loaded) echo("WARN: shell db not loaded yet; run load()")
  }

  private Ref:Dict byId := [:]
  private Bool loaded := false
}

**************************************************************************
** ShellDbFuncs
**************************************************************************

const class ShellDbFuncs : AbstractShellFuncs
{
  **
  ** Read from virtual database the first record which matches filter.
  ** If no matches found throw UnknownRecErr or null based
  ** on checked flag.  See `readAll` for how filter works.
  **
  ** Examples:
  **   read(site)                 // read any site rec
  **   read(site and dis=="HQ")   // read site rec with specific dis tag
  **   read(chiller)              // raise exception if no recs with chiller tag
  **   read(chiller, false)       // return null if no recs with chiller tag
  **
  @Axon
  static Dict? read(Expr filterExpr, Expr checked := Literal.trueVal)
  {
    filter := filterExpr.evalToFilter(cx)
    check := checked.eval(cx)
    return cx.db.read(filter, check, cx)
  }

  **
  ** Read a record from the virtual database by 'id'.  If not found
  ** throw UnknownRecErr or return null based on checked flag.
  **
  ** Examples:
  **    readById(@2b00f9dc-82690ed6)    // read by ref literal
  **    readById(id)                    // read using variable
  **    readById(equip->siteRef)        // read from ref tag
  **
  @Axon
  static Dict? readById(Ref? id, Bool checked := true)
  {
    cx.db.readById(id ?: Ref.nullRef, checked)
  }

  **
  ** Read a list of record ids from the virtual database into a grid.
  ** The rows in the result correspond by index to the ids list.  If
  ** checked is true, then every id must be found in the database or
  ** UnknownRecErr is thrown.  If checked is false, then an unknown
  ** record is returned as a row with every column set to null (including
  ** the 'id' tag).
  **
  ** Examples:
  **   // read two relative refs
  **   readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a])
  **
  **   // return null for a given id if it does not exist
  **   readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a], false)
  **
  @Axon
  static Grid readByIds(Ref[] ids, Bool checked := true)
  {
    cx.db.readByIds(ids, checked)
  }

  **
  ** Reall all records from the virtual database which match the filter.
  **
  ** Options:
  **   - 'limit': max number of recs to return
  **   - 'sort': sort by display name
  **
  ** Examples:
  **   readAll(site)                      // read all site recs
  **   readAll(equip and siteRef==@xyz)   // read all equip in a given site
  **   readAll(equip, {limit:10})         // read up to ten equips
  **   readAll(equip, {sort})             // read all equip sorted by dis
  **
  @Axon
  static Grid readAll(Expr filterExpr, Expr? optsExpr := null)
  {
    filter := filterExpr.evalToFilter(cx)
    opts := optsExpr == null ? Etc.emptyDict : (Dict?)optsExpr.eval(cx)
    return cx.db.readAll(filter, opts, cx)
  }

  **
  ** Return the number of records in the virtual database which match
  ** the given filter expression.
  **
  ** Examples:
  **   readCount(point)    // return number of recs with point tag
  **
  @Axon
  static Number readCount(Expr filterExpr)
  {
    filter := filterExpr.evalToFilter(cx)
    return Number(cx.db.readCount(filter, cx))
  }

  **
  ** Load virtual database from local file.  The file is identified using
  ** an URI with Unix forward slash conventions.  The file must have one
  ** of the following file extensions: zinc, json, trio, or csv.
  ** Each record should define an 'id' tag, or if missing one will
  ** assigned automatically.
  **
  ** Examples:
  **   load(`folder/site.json`)
  **
  @Axon
  static Obj load(Obj file)
  {
    cx.db.load(file, cx)
    return noEcho
  }
}