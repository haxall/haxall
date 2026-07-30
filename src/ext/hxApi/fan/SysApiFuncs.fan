//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jul 2026  Brian Frank  Creation
//

using xeto
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

  ** Read the first entity which matches [filter](ph.doc::Filters).
  ** If no matches found raise error or return null based on checked
  ** flag.  If there are multiple matches it is indeterminate which one is
  ** returned.
  **
  ** Examples:
  **
  **     read(Site)                 // read any entity which subtypes Site
  **     read(Site and dis=="HQ")   // read site with specific dis tag
  **     read(Room)                 // raise error if no room entities
  **     read(Room, false)          // return null if no room entities
  @Api @Axon
  static Dict? read(Expr filterExpr, Expr checked := Literal.trueVal)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    check := checked.eval(cx)
    return cx.db.read(filter, check)
  }

  ** Read an entity by `id`.  If not found raise error or
  ** return null based on checked flag.
  **
  ** Examples:
  **
  **      readById(@2b00f9dc-82690ed6)
  **      readById(@2b00f9dc-82690ed6, false)
  @Api @Axon
  static Dict? readById(Ref? id, Bool checked := true)
  {
    curContext.db.readById(id ?: Ref.nullRef, checked)
  }

  ** Read a list of entities by their ids into a grid.  The rows in the
  ** result correspond by index to the ids list.  If checked is true,
  ** then every id must be found or an error is raised.  If checked
  ** is false, then an unknown entity is returned as a row with every column
  ** set to null (including the `id` tag).
  **
  ** Examples:
  **
  **     readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a])
  **     readByIds([@2af6f9ce-6ddc5075, @2af6f9ce-2d56b43a], false)
  @Api @Axon
  static Grid readByIds(Ref[] ids, Bool checked := true)
  {
    curContext.db.readByIds(ids, checked)
  }

  ** Read all entities which match the [filter](ph.doc::Filters).
  **
  ** Options:
  **   - `limit`: max number of entities to return
  **   - `sort`: sort by display name
  **   - `search`: platform specific search pattern
  **   - `gridMeta`: dict to use for the result's grid level meta
  **
  ** Examples:
  **
  **     readAll(Site)                      // read all site entities
  **     readAll(Equip and siteRef==@xyz)   // read all equip in a given site
  **     readAll(Equip, {limit:10})         // read up to ten equips
  **     readAll(Equip, {sort})             // read all equip sorted by dis
  @Api @Axon
  static Grid readAll(Expr filterExpr, Expr? optsExpr := null)
  {
    cx := curContext
    filter := filterExpr.evalToFilter(cx)
    opts := optsExpr == null ? Etc.dict0 : (Dict?)optsExpr.eval(cx)
    return cx.db.readAll(filter, opts)
  }

//////////////////////////////////////////////////////////////////////////
// Server
//////////////////////////////////////////////////////////////////////////

  ** Return summary information about the server; see `sys.api::AboutInfo`
  ** for the tags a server should report where applicable.  Vendors may
  ** add their own tags.
  **
  ** This is typically the first call a client makes to discover what it
  ** is talking to.  Use `libs` to discover the installed libs and their
  ** versions.
  **
  ** See [ph.doc::Ops#about].
  @Api @Axon
  static Dict about() { curContext.about }

  ** Close the client's current session and release any server side
  ** resources held by it.  Any future requests using the session's
  ** authentication token are rejected and the client must reauthenticate.
  **
  ** Servers which do not maintain per-session state may implement this
  ** as a no-op.  There is no result: v5 returns nothing and v4 encodes
  ** it as the empty grid its clients expect.
  **
  ** See [ph.doc::Ops#close].
  @Api @Axon
  static Obj? close()
  {
    cx := curContext
    cx.sys.session.close(cx.session)
    return null
  }

  ** Report the operations this server supports, one row per op, matching
  ** the `sys.api::OpInfo` spec.  This is the v5 format which describes
  ** the live xeto namespace; v4 clients are served the legacy def format
  ** instead by `hxApi::ApiDispatchV4Ops` before this function is reached.
  **
  ** See `sys.api::Funcs.ops`.
  @Api @Axon
  static Grid ops()
  {
    gb := GridBuilder()
    gb.setMeta(Etc.dict1("of", opInfoRef))
    gb.addCol("qname")
      .addCol("doc")
      .addCol("noSideEffects").addCol("signature")
      .addCol("spec")

    acc := Spec[,]
    curContext.ns.libs.each |lib|
    {
      lib.funcs.list.each |f| { if (f.meta.has("op")) acc.add(f) }
    }
    acc.sort |a, b| { a.func.qname <=> b.func.qname }

    acc.each |f|
    {
      gb.addRow([
        f.func.qname,
        Etc.firstSentence(f["doc"] as Str),
        f.meta["noSideEffects"],
        f.func.signature,
        opInfoRef,
      ])
    }
    return gb.toGrid
  }

  private static const Ref opInfoRef := Ref("sys.api::OpInfo")

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Current context
  private static Context curContext() { Context.cur }
}

