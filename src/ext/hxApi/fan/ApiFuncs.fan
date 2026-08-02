//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using xeto
using web
using haystack
using axon
using folio
using hx

**
** Haxall "hx.api" axon functions which define the HTTP API operations
** specific to Haxall
**
@Gen
const class ApiFuncs
{

//////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  ** Evaluate an expression and return the result as a grid.  The request
  ** grid has a single row with an `expr` column.  If the expression parses
  ** as a [filter](ph.doc::Filters) such as "site and area > 1000" then it
  ** is read as a query, otherwise it is evaluated as an Axon expression.
  **
  ** Also see `axon::Funcs.eval` which evaluates an expression directly without
  ** the filter convenience, and [hx.doc.skyspark::Ops#eval] for the HTTP
  ** API details.
  @Api @Axon
  static Grid eval(Grid req)
  {
    if (req.isEmpty) throw Err("Request grid is empty")
    expr := (Str)req.first->expr
    return Etc.toGrid(curContext.evalOrReadAll(expr))
  }

//////////////////////////////////////////////////////////////////////////
// Commit
//////////////////////////////////////////////////////////////////////////

  ** Add, update, or remove entities in the database.  The grid meta
  ** `commit` tag selects the mode:
  **   - "add": each row is a new entity; the `id` column is optional and
  **     is generated when omitted
  **   - "update": each row must have `id` and `mod` columns, where `mod`
  **     is the entity's current modified timestamp used for optimistic
  **     concurrency.  Grid meta may specify the `force` marker to skip
  **     the concurrency check, and `transient` to avoid persisting.
  **   - "remove": each row must have `id` and `mod` columns; grid meta
  **     may specify the `force` marker
  **
  ** Returns a grid of the resulting entities for add and update, or an
  ** empty grid for remove.  Requires admin permission.
  **
  ** Also see `hx::Funcs.commit` which takes a list of diffs, and
  ** [hx.doc.skyspark::Ops#commit] for the HTTP API details.
  @Api @Axon { admin = true }
  static Grid commit(Grid req)
  {
    cx := curContext
    if (!cx.user.isAdmin) throw PermissionErr("Missing 'admin' permission: commit")
    mode := req.meta->commit
    switch (mode)
    {
      case "add":    return commitAdd(req, cx)
      case "update": return commitUpdate(req, cx)
      case "remove": return commitRemove(req, cx)
      default:       throw ArgErr("Unknown commit mode: $mode")
    }
  }

  private static Grid commitAdd(Grid req, Context cx)
  {
    diffs := Diff[,]
    req.each |row|
    {
      changes := Str:Obj?[:]
      Ref? id := null
      row.each |v, n|
      {
        if (n == "id") { id = v; return }
        changes.add(n, v)
      }
      diffs.add(Diff.makeAdd(changes, id ?: Ref.gen))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private static Grid commitUpdate(Grid req, Context cx)
  {
    flags := 0
    if (req.meta.has("force"))     flags = flags.or(Diff.force)
    if (req.meta.has("transient")) flags = flags.or(Diff.transient)

    diffs := Diff[,]
    req.each |row|
    {
      old := Etc.makeDict(["id":row.id, "mod":row->mod])
      changes := Str:Obj?[:]
      row.each |v, n|
      {
        if (n == "id" || n == "mod") return
        changes.add(n, v)
      }
      diffs.add(Diff(old, changes, flags))
    }
    newRecs := cx.db.commitAll(diffs).map |d->Dict| { d.newRec }
    return Etc.makeDictsGrid(null, newRecs)
  }

  private static Grid commitRemove(Grid req, Context cx)
  {
    flags := Diff.remove
    if (req.meta.has("force")) flags = flags.or(Diff.force)

    diffs := Diff[,]
    req.each |row| { diffs.add(Diff(row, null, flags)) }
    cx.db.commitAll(diffs)
    return Etc.makeEmptyGrid
  }

//////////////////////////////////////////////////////////////////////////
// Ext
//////////////////////////////////////////////////////////////////////////

  ** Route an HTTP request to an extension's web handler.  The first name
  ** of the URI path after the op selects the extension route, and the
  ** remainder of the path is passed through to that extension.
  @Api
  static Void ext()
  {
    cx  := curContext
    req := cx.webReq
    res := cx.webRes

    // by the time the op is called the modBase is `/api/{proj}/ext/` which
    // means the route name is the first element of modRel
    routeName := req.modRel.path.getSafe(0) ?: ""
    mod := cx.rt.exts.webRoutes.get(routeName)
    if (mod == null) throw ApiErr.unknownEntityErr("Unknown ext route: $routeName")

    // dispatch to web mod
    req.mod = mod
    req.modBase = `/api/${cx.rt.name}/ext/${routeName}/`
    mod.onService
  }

//////////////////////////////////////////////////////////////////////////
// File
//////////////////////////////////////////////////////////////////////////

  ** Download or upload a file in the virtual file system.  The URI path
  ** after the op is the file path.  A GET downloads the file with full
  ** ETag, Last-Modified, and range request support.  A POST or PUT
  ** uploads the request body to that path, where a path under
  ** "/uploads/{lib}/" delegates to that extension's upload handler.
  @Api
  static Obj? file()
  {
    // this op interprets the method itself -- GET downloads and POST/PUT
    // upload -- so it reads the request directly and takes no params.  Both
    // branches return a value for the dispatcher to write: a file is served
    // as a download, an upload result is encoded as a grid
    cx  := curContext
    req := cx.webReq
    res := cx.webRes

    // {api file}/{path} => /{path}
    path := `/` + req.modRel

    // check for proj-relative path
    subMount := path.path.first
    if (!cx.sys.isProj && subMount != "proj")
    {
      try
      {
        if (cx.sys.file.resolve(`/proj/${cx.rt.name}/${subMount}/`).exists)
          path = `/proj/${cx.rt.name}${path}`
      }
      catch (Err ignore) { }
    }

    switch (req.method)
    {
      case "GET":
        return fileDownload(cx, path)
      case "POST":
      case "PUT":
        // fall-through
        return fileUpload(cx, req, res, path)
      default:
        throw ApiErr.notImplementedErrMethod(req.method)
    }
  }

  ** Note that download is only supported for the file ext
  private static File? fileDownload(Context cx, Uri path)
  {
    if (path.isDir) throw ApiErr.unknownEntityErr("Not a file: $path")
    return cx.sys.file.resolve(path)
  }

  private static Obj? fileUpload(Context cx, WebReq req, WebRes res, Uri path)
  {
    Ext ext := cx.sys.file

    // handle ext delegation /uploads/<xeto lib>/<path>
    names := path.path
    if (names.first == "uploads")
    {
      ext  = cx.proj.ext(names[1])
      path = path.getRangeToPathAbs(2..-1)
    }

    try
    {
      opts := Etc.dict1("path", path)
      return cx.asCur { ext.uploadHandler(req, res, opts).upload }
    }
    catch (Err err)
    {
      err = Err("Upload failed by ${cx.user} for ${req.uri} (${path})", err)
      ext.log.err(err.msg, err)
      throw err
    }
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Current context
  private static Context curContext() { Context.cur }

}

