//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jul 2026  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using axon
using folio
using hx

**
** Core "sys.api" axon functions which define the network API
** supported by all Xeto servers
**
@Gen
const class SysApiFuncs
{

//////////////////////////////////////////////////////////////////////////
// Database Reads
//////////////////////////////////////////////////////////////////////////

  ** Read from database the first record which matches [filter](ph.doc::Filters).
  ** If no matches found throw UnknownRecErr or null based on checked
  ** flag.  If there are multiple matches it is indeterminate which one is
  ** returned.  See [readAll()] for how filter works.
  **
  ** Examples:
  **
  **     read(site)                 // read any site rec
  **     read(site and dis=="HQ")   // read site rec with specific dis tag
  **     read(chiller)              // raise exception if no recs with chiller tag
  **     read(chiller, false)       // return null if no recs with chiller tag
  @Api @Axon
  static Dict? read(Expr filterExpr, Expr checked := Literal.trueVal)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    check := checked.eval(cx)
    return cx.db.read(filter, check)
  }

  ** Read a record from database by `id`.  If not found
  ** throw UnknownRecErr or return null based on checked flag.
  ** In Haxall all refs are relative, but in SkySpark refs may
  ** be prefixed with something like "p:projName:r:".  This function
  ** will accept both relative and absolute refs.
  **
  ** Examples:
  **
  **      readById(@2b00f9dc-82690ed6)          // relative ref literal
  **      readById(@:demo:r:2b00f9dc-82690ed6)  // project absolute literal
  **      readById(id)                          // read using variable
  **      readById(equip->siteRef)              // read from ref tag
  @Api @Axon
  static Dict? readById(Ref? id, Bool checked := true)
  {
    curContext.db.readById(id ?: Ref.nullRef, checked)
  }

  ** Read a list of record ids into a grid.  The rows in the
  ** result correspond by index to the ids list.  If checked is true,
  ** then every id must be found in the database or UnknownRecErr
  ** is thrown.  If checked is false, then an unknown record is
  ** returned as a row with every column set to null (including
  ** the `id` tag).  Either relative or project absolute refs may
  ** be used.
  **
  ** Examples:
  **
  **     // read two relative refs
  **     readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a])
  **
  **     // read two project absolute refs
  **     readByIds([@p:demo:r:2af6f9ce-6ddc5075, @p:demo:r:2af6f9ce-2d56b43a])
  **
  **     // return null for a given id if it does not exist
  **     readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a], false)
  @Api @Axon
  static Grid readByIds(Ref[] ids, Bool checked := true)
  {
    curContext.db.readByIds(ids, checked)
  }

  ** Read all records from the database which match the [filter](ph.doc::Filters).
  ** The filter must be an expression which matches the filter structure.
  ** String values may parsed into a filter using [parseFilter()] function.
  **
  ** Options:
  **   - `limit`: max number of recs to return
  **   - `sort`: sort by display name
  **   - `search`: search pattern to apply in addition to the
  **     filter; see [parseSearch()]
  **   - `trash`: include recs with the `trash` tag
  **   - `gridMeta`: dict to use for the result's grid level meta
  **
  ** Examples:
  **
  **     readAll(site)                      // read all site recs
  **     readAll(equip and siteRef==@xyz)   // read all equip in a given site
  **     readAll(equip, {limit:10})         // read up to ten equips
  **     readAll(equip, {sort})             // read all equip sorted by dis
  @Api @Axon
  static Grid readAll(Expr filterExpr, Expr? optsExpr := null)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    opts := optsExpr == null ? Etc.dict0 : (Dict?)optsExpr.eval(cx)
    return cx.db.readAll(filter, opts)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Current context
  private static Context curContext() { Context.cur }
}

