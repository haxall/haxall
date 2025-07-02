//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jun 2012  Brian Frank  Creation
//

using obix
using xml
using xeto
using haystack
using hx

**
** ObixWatch wraps HxWatch as ObixModWatch
**
class ObixWatch : ObixModWatch
{
  new make(ObixWebMod mod, HxWatch watch)
  {
    this.mod = mod
    this.watch = watch
    this.recsUri = mod.req.modBase + `rec/`
  }

  const ObixWebMod mod
  const HxWatch watch
  const Uri recsUri

  override Str id() { watch.id }

  override Duration lease
  {
    get { watch.lease }
    set { watch.lease = it }
  }

  override ObixObj[] add(Uri[] uris)
  {
    // map uris to ids (some may be in error)
    validIds := Ref[,]
    idByIndex := Ref?[,]
    uris.each |uri|
    {
      id := uriToId(uri)
      idByIndex.add(id)
      if (id != null) validIds.add(id)
    }

    // add the uris to the watch
    watch.addAll(validIds)

    // read ids successfully added to watch to get recs as grid
    recList := watch.rt.db.readByIdsList(watch.list, false)

    // map recs by id
    recsById := Ref:Dict?[:]
    recList.each |rec| { if (rec != null) recsById[rec.id] = rec }

    // now map back to objects
    objs := ObixObj[,]
    uris.each |uri, i|
    {
      id := idByIndex[i]
      Dict? rec := null
      if (id != null) rec = recsById[id]

      ObixObj? obj
      if (rec == null)
      {
        obj = ObixErr.toUnresolvedObj(uri)
        if (id == null)
          obj.display = "Watch URI must be: ${recsUri}{id}/"
      }
      else
      {
        obj = recToObix(rec)
      }
      objs.add(obj)
    }
    return objs
  }

  override Void remove(Uri[] uris)
  {
    ids := Ref[,]
    uris.each |uri|
    {
      id := uriToId(uri)
      if (id != null) ids.add(id)
    }
    watch.removeAll(ids)
  }

  override ObixObj[] pollChanges()
  {
    doPoll(watch.poll)
  }

  override ObixObj[] pollRefresh()
  {
    doPoll(watch.poll(Duration.defVal))
  }

  private ObixObj[] doPoll(Dict[] recs)
  {
    objs := ObixObj[,]
    objs.capacity = recs.size
    recs.each |rec|
    {
      obj := recToObix(rec)
      objs.add(obj)
    }
    return objs
  }

  override Void delete()
  {
    watch.close
  }

  private ObixObj recToObix(Dict rec)
  {
    proxy := ObixRec(recParentProxy(), rec.id.toStr, rec)
    proxy.isRoot = false
    return proxy.read
  }

  private once ObixRecs recParentProxy()
  {
    ObixLobby(mod).get("rec")
  }

  private Ref? uriToId(Uri uri)
  {
    // we only support uris formatted exactly as:
    //   /api/{proj}/ext/obix/rec/{id}/
    if (uri.parent != recsUri) return null
    if (!uri.isDir) return null
    return Ref.fromStr(uri.path[-1], false)
  }

}

