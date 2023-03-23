//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Mar 2023  Brian Frank  Creation
//

using web
using data
using haystack
using axon
using folio

**
** Implementation of shell 'load()' function
**
internal class ShellLoader
{
  new make(ShellContext cx, Uri uri, Dict opts)
  {
    this.cx          = cx
    this.uri         = uri
    this.opts        = opts
    this.useShortIds = opts.has("shortIds")
  }

  Obj? load()
  {
    echo("LOAD: loading '$uri' $opts ...")
    grid := readUri(uri)
    shortIdWidth = grid.size.toHex.size

    // normalize recs
    grid = grid.map |rec| { normRec(rec) }

    // map grid into byId table
    diffs := Diff[,]
    grid.each |Dict rec|
    {
      id := rec["id"] as Ref ?: Ref.gen
      rec = Etc.dictRemoveAll(rec, ["id", "mod"])
      diffs.add(Diff.makeAdd(rec, id))
    }
    cx.db.commitAll(diffs)

    echo("LOAD: loaded $grid.size recs")
    return ShellContext.noEcho
  }

  private Grid readUri(Uri uri)
  {
    // we use URI extension type even for HTTP
    if (uri.scheme == "http" || uri.scheme == "https")
      return readStr(uri, WebClient(uri).getStr)
    else
      return readStr(uri, uri.toFile.readAllStr)
  }

  private Grid readStr(Uri uri, Str s)
  {
    switch (uri.ext)
    {
      case "zinc": return ZincReader(s.in).readGrid
      case "json": return JsonReader(s.in).readGrid
      case "trio": return TrioReader(s.in).readGrid
      case "csv":  return CsvReader(s.in).readGrid
      default:     throw ArgErr("ERROR: unknown file type [$uri.name]")
    }
  }

  private Dict normRec(Dict rec)
  {
    acc := Str:Obj[:]
    rec.each |v, n|
    {
      if (FolioUtil.isUncommittable(n)) return
      if (v is Ref) v = normRef(v)
      acc[n] = v
    }
    return Etc.dictFromMap(acc)
  }

  private Ref normRef(Ref id)
  {
    id = id.toProjRel
    if (useShortIds)
    {
      short := shortIds[id]
      if (short == null) shortIds[id] = short = Ref(shortIds.size.toHex(shortIdWidth).upper)
      id = short
    }
    return id
  }

  private ShellContext cx
  private Uri uri
  private Dict opts
  private Bool useShortIds
  private Int shortIdWidth
  private Ref:Ref shortIds := [:]

}


