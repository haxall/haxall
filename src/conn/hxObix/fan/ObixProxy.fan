//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Mar 2010  Brian Frank  Creation
//

using web
using obix
using xeto
using haystack
using hx

**
** ObixProxy is used to represent an oBIX resource which
** can be read, written, or invoked.
**
abstract class ObixProxy
{
  ** Constructor
  new make(ObixProxy parent, Str name)
  {
    this.lobbyRef  = parent.lobby
    this.parentRef = parent
    this.uri       = "${parent.uri}${name}/".toUri
  }

  ** Constructor for lobby only
  new makeLobby()
  {
    this.lobbyRef = this
    this.uri      = ``
  }

  ** Lobby root proxy
  ObixLobby lobby() { lobbyRef }
  private ObixLobby lobbyRef

  ** Parent proxy or null if this is the Lobby
  ObixProxy? parent() { parentRef }
  private ObixProxy? parentRef

  ** URI relative to ObixWebMod
  const Uri uri

  ** Project associated with this proxy
  Proj rt() { lobby.mod.rt }

  ** Get child proxy by name, or null
  virtual ObixProxy? get(Str name) { null }

  ** Read the oBIX object representation
  abstract ObixObj read()

  ** Write this proxy or throw ReadonlyErr if not writable
  virtual ObixObj write(ObixObj arg) { throw ReadonlyErr() }

  ** Invoke this proxy or throw UnsupportedErr if not an operation
  virtual ObixObj invoke(ObixObj arg) { throw UnsupportedErr() }

  ** Absolute URI to use as root href
  Uri absBaseUri()
  {
    lobby.mod.req.absUri + lobby.mod.req.modBase + uri
  }

  ** Get URI as server relative URI
  Uri idToUri(Ref id)
  {
    lobby.mod.req.modBase + `rec/${id.toStr}/`
  }

  ** Get URI as server relative URI
  Uri queryToUri(Str query)
  {
    lobby.mod.req.modBase + `query/$query/`
  }
}

**************************************************************************
** ObixLobby
**************************************************************************

**
** ObixLobby represents the root proxy object.
**
class ObixLobby : ObixProxy
{
  new make(ObixWebMod mod) : super.makeLobby() { this.mod = mod }

  const ObixWebMod mod

  override ObixProxy? get(Str name)
  {
    if (name == "rec") return ObixRecs(this)
    if (name == "query") return ObixQuery(this)
    return null
  }

  override ObixObj read()
  {
    obj := mod.defaultLobby
    obj.add(ObixObj { name = "sites"; href=`query/site/` })
    obj.add(ObixObj { name = "equip"; href=`query/equip/` })
    obj.add(ObixObj { name = "points"; href=`query/point/` })
    obj.add(ObixObj { name = "histories"; href=`query/his/` })
    return obj
  }
}

**************************************************************************
** ObixRecs
**************************************************************************

**
** ObixRecs represents the "rec/" namespace
**
class ObixRecs : ObixProxy
{
  new make(ObixProxy parent) : super.make(parent, "rec") {}

  override ObixProxy? get(Str name)
  {
    // try resolve rec by id or sys name
    id := Ref.fromStr(name, false)
    Dict? rec := id != null ? rt.db.readById(id, false) : rt.db.read(Filter.eq("name", name), false)
    if (rec != null) return ObixRec(this, name, rec)
    return null
  }

  override ObixObj read()
  {
    ObixObj
    {
      href = absBaseUri
      ObixObj { name = "comment"; val="use rec/{id|name} to access a record" },
    }
  }
}

**************************************************************************
** ObixQuery
**************************************************************************

**
** ObixQuery provides a flat list which matches a filter
**
class ObixQuery : ObixProxy
{
  new make(ObixProxy parent) : super.make(parent, "query") {}

  override ObixProxy? get(Str filter) { ObixFilter(this, filter) }

  override ObixObj read()
  {
    ObixObj
    {
      href = absBaseUri
      ObixObj { name = "comment"; val="use query/{filter} to query by tag" },
    }
  }
}

**************************************************************************
** ObixFilter
**************************************************************************

**
** ObixFilter implements a ObixQuery filter
**
class ObixFilter : ObixProxy
{
  new make(ObixProxy parent, Str filter) : super.make(parent, filter) {}

  override ObixObj read()
  {
    list := ObixObj { href = absBaseUri }

    filter := uri.name

    rt.db.readAllList(Filter(filter)).each |rec|
    {
      list.add(ObixObj
      {
        it.elemName = "ref"
        it.displayName = rec.dis
        it.href = idToUri(rec.id)
        it.contract = ObixAspect.toContract(rec)
      })
    }
    return list
  }
}

**************************************************************************
** ObixRec
**************************************************************************

**
** ObixRec is used to map a Folio record to an oBIX object.
**
class ObixRec : ObixProxy
{
  new make(ObixProxy parent, Str name, Dict rec) : super(parent, name)
  {
    this.rec = rec
    this.aspects = ObixAspect.toAspects(rec)
  }

  ** Folio record
  const Dict rec

  ** Is this a root object
  Bool isRoot := true

  ** Aspects which implement additional oBIX contract functionality
  ObixAspect[] aspects := [,]

  override ObixProxy? get(Str name)
  {
    // aspects trump folio tags
    for (i:=0; i<aspects.size; ++i)
    {
      aspectProxy := aspects[i].get(this, name)
      if (aspectProxy != null) return aspectProxy
    }

    // lookup tag
    tagVal := rec[name]
    if (tagVal != null) return ObixTag(this, rec, name, tagVal)
    return null
  }

  override ObixObj read()
  {
    obj := ObixObj()
    obj.href = isRoot ? absBaseUri : idToUri(rec.id)
    obj.displayName = rec.dis

    // walk all the aspects to get their contracts and children objects
    contracts := Uri[,]
    aspects.each |aspect|
    {
      contracts.add(aspect.contract)
      aspect.read(this, obj)
    }

    // get if site, get equip children
    if (rec.has("site"))
    {
      equipsUri :=  queryToUri("equip and siteRef==${rec.id.toCode}")
      obj.add(ObixObj { elemName = "ref"; displayName = "equips"; href = equipsUri })
    }

    // get if equip, get point children
    if (rec.has("equip"))
    {
      pointsUri :=  queryToUri("point and equipRef==${rec.id.toCode}")
      obj.add(ObixObj { elemName = "ref"; displayName = "points"; href = pointsUri })
    }

    // add each tag as a child object unless it conflicts
    // with a child added by one of the aspects
    rec.each |v, n|
    {
      if (v === Marker.val) { contracts.add(`tag:$n`); return }
      if (n == "id") return
      if (n == "dis") { obj.displayName = v }
      if (!obj.has(n)) obj.add(tagToObj(n, v))
    }

    if (!contracts.isEmpty) obj.contract = Contract(contracts)
    return obj
  }

  ObixObj tagToObj(Str name, Obj val)
  {
    // Refs become <ref> elements
    if (val is Ref)
    {
      ref := (Ref)val
      obj := ObixObj { it.name = name; it.elemName = "ref"; href = idToUri(ref) }
      if (ref.disVal != null) obj.display = ref.disVal
      return obj
    }

    // Number -> <real>
    if (val is Number)
    {
      num := (Number)val
      return ObixObj { it.name = name; it.val = num.toFloat; it.unit = num.unit; href = name.toUri }
    }

    // Coord -> Str
    if (val is Coord)
    {
      return ObixObj { it.name = name; it.val = val.toStr; href = name.toUri }
    }

    // map Axon scalar to one of the standard oBIX scalars
    if (val is Bin) val = val.toStr
    return ObixObj { it.name = name; it.val = val; href = name.toUri }
  }
}

**************************************************************************
** ObixTag
**************************************************************************

**
** ObixTag is used to map a single tag name/value pair of a record.
**
class ObixTag : ObixRec
{
  new make(ObixRec parent, Dict rec, Str tagName, Obj tagVal)
    : super(parent, tagName, rec)
  {
    this.tagName = tagName
    this.tagVal  = tagVal
  }

  const Str tagName
  const Obj tagVal

  override ObixObj read()
  {
    obj := tagToObj(tagName, tagVal)
    obj.href = absBaseUri
    return obj
  }
}

**************************************************************************
** ObixVal
**************************************************************************

**
** ObixVal is a proxy which wraps a simple value.
**
class ObixVal : ObixProxy
{
  new make(ObixProxy parent, Str name, Obj? val) : super.make(parent, name)
  {
    this.val = val
  }

  Obj? val

  override ObixObj read() { ObixObj { href = absBaseUri; it.val = this.val } }
}

