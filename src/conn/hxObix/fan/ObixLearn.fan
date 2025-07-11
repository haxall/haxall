//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    27 Jun 2012  Brian Frank  Create
//

using obix
using xeto
using haystack
using hxConn

**
** ObixLearn handles learning details
**
internal class ObixLearn
{
  new make(ObixDispatch conn, Uri? learnUri)
  {
    this.conn     = conn
    this.client   = conn.client
    this.learnUri = learnUri ?: ``
  }

  Grid? learn()
  {
    t1 := Duration.now
    readBaseObj
    addObj(baseObj)
    addExtent
    learnRefs
    learnMore
    fixIcons
    t2 := Duration.now
    echo("ObixLearn $learnUri [${(t2-t1).toLocale}]")
    return toGrid
  }

  private Void readBaseObj()
  {
    baseObj = client.read(learnUri)
    baseUri = baseObj.href
  }

  private Void addExtent()
  {
    baseObj.each |child|
    {
      addObj(child)
      if (child.elemName == "list")
        child.each |grandchild| { addObj(grandchild) }
    }
  }

  private Void addObj(ObixObj obj)
  {
    // skip objects without their own href
    if (obj.href == null) return
    objs.add(makeObj(obj))
  }

  private ObixLearnObj makeObj(ObixObj obj)
  {
    if (conn.isNiagara) return ObixNiagaraObj(this, obj)
    return ObixLearnObj(this, obj)
  }

  private Void learnRefs()
  {
    // do batch deep read of <ref> that is Point or History
    uris := Uri[,]
    uriToObj := Int:Int[:]
    objs.each |obj, i|
    {
      if (i == 0) return
      if (obj.obj.elemName != "ref") return
      if (!obj.isPoint && !obj.isHistory) return
      uriToObj[uris.size] = i
      uris.add(obj.uri)
    }
    if (uris.isEmpty) return

    // do the batch read, then replace <ref> objects with their deep read
    res := client.batchRead(uris)
    res.each |r, i| { objs[uriToObj[i]] = makeObj(r) }
  }

  private Void learnMore()
  {
    // let each object do another level of read/invoke
    // to gather further information - objects set this up
    // by setting their more* fields
    batchReq := ObixObj { elemName = "list"; contract = Contract.batchIn }
    batchMores := ObixLearnMore[,]
    objs.each |obj|
    {
      // if no moreReq we can skip
      more := obj.more
      if (more == null) return

      // add read|invoke uri to our batch request
      req := ObixObj{elemName = "uri"; contract = more.req; val = obj.more.uri }
      if (more.arg != null) { more.arg.name = "in"; req.add(more.arg) }
      batchReq.add(req)

      // add keep track of object for more result callback
      batchMores.add(more)
    }

    // if we have mores, then do request
    if (batchMores.isEmpty) return
    if (client.batchUri == null) throw Err("ObixClient.batchUri not configured")
    batchRes := client.invoke(client.batchUri, batchReq)
    batchRes.list.each |res, i|
    {
      batchMores[i].onResult(res)
    }
  }

  /*
  private Void mapExistingRefs()
  {
    // find all the existing points in the database which are already
    // mapped using this connector and stick them into a lookup table
    curRefs   := Uri:Ref[:]
    writeRefs := Uri:Ref[:]
    hisRefs   := Uri:Ref[:]
    pts := conn.proj.getAll("obixConnRef == $conn.id.toCode")
    pts.each |pt|
    {
      cur := pt["obixCur"] as Uri
      if (cur != null) curRefs[cur] = Ref(pt.id.id, pt.dis)

      write := pt["obixWrite"] as Uri
      if (write != null) writeRefs[write] = Ref(pt.id.id, pt.dis)

      his := pt["obixHis"] as Uri
      if (his != null) hisRefs[his] = Ref(pt.id.id, pt.dis)
    }

    // now map all the learn objects
    objs.each |obj|
    {
      if (obj.obixCur   != null) obj.curRef   = curRefs[obj.obixCur]
      if (obj.obixWrite != null) obj.writeRef = writeRefs[obj.obixWrite]
      if (obj.obixHis   != null) obj.hisRef   = hisRefs[obj.obixHis]
    }
  }
  */

  private Void fixIcons()
  {
    baseUri := conn.ext.web.uri.toStr + "icon/${conn.id}"
    objs.each |obj|
    {
      if (obj.icon != null && obj.icon.toStr.startsWith("/"))
        obj.icon = "${baseUri}${obj.icon}".toUri
    }
  }

  private Grid toGrid()
  {
    meta := ["obixConnRef":conn.id, "uri":learnUri]
    cols := ["dis", "learn", "point",
             "kind", "unit", "enum", "hisInterpolate",
             "obixCur", "obixWrite", "obixHis",
             "icon"]
    rows := Obj?[,]
    objs.each |obj|
    {
      rows.add([obj.dis,  obj.learn, obj.isPoint ? Marker.val : null,
                obj.kind, obj.unit, obj.enum, obj.hisInterpolate,
                obj.obixCur, obj.obixWrite, obj.obixHis,
                obj.icon])

    }
    return Etc.makeListsGrid(meta, cols, null, rows)
  }

  ObixDispatch conn                 // make
  ObixClient client                 // make
  Uri learnUri                      // make
  ObixObj? baseObj                  // readBaseObj
  Uri? baseUri                      // readBaseObj
  ObixLearnObj[] objs := [,]        // addObj
}

**************************************************************************
** ObixLearnObj
**************************************************************************

internal class ObixLearnObj
{
  new make(ObixLearn parent, ObixObj obj)
  {
    this.parent     = parent
    this.obj        = obj
    this.uri        = toUri
    this.dis        = toDis
    this.learn      = obj === parent.baseObj ? null : uri
    this.icon       = obj.icon
    this.isStr      = ObixUtil.contractToDis(obj.contract)
    this.isPoint    = obj.contract.has(`obix:Point`)
    this.isWritable = obj.contract.has(`obix:WritablePoint`)
    this.isHistory  = obj.contract.has(`obix:History`)
    this.kind       = toKind(obj)
    this.unit       = obj.unit?.symbol
    this.obixCur    = kind != null ? uri : null
    this.obixWrite  = toWriteUri
    this.obixHis    = isHistory ? uri : null
  }

  private Uri toUri()
  {
    // safest course both Niagara, SkySpark is to use
    // server absolute URI for the address
    parent.baseUri.plus(obj.href).relToAuth
  }

  virtual Str toDis()
  {
    if (obj.displayName != null) return obj.displayName
    if (obj.name != null) return unescapeName(obj.name)
    if (obj.href != null) return unescapeName(obj.href.name)
    return obj.contract.toStr
  }

  virtual Str unescapeName(Str name) { name }

  virtual Str? toKind(ObixObj val)
  {
    type := val.valType
    if (type == null)    return null
    if (type === Float#) return Kind.number.name
    if (type === Bool#)  return Kind.bool.name
    return Kind.str.name
  }

  virtual Uri? toWriteUri()
  {
    if (!isWritable) return null
    op := obj.get("writePoint", false)
    if (op == null) return null
    return uri + op.href
  }

  virtual Void onMore(ObixObj res) {}

  override Str toStr() { "$typeof.name $obj" }

  ObixLearn parent
  ObixObj obj
  Bool isPoint
  Bool isWritable
  Bool isHistory
  Uri uri
  Str  dis
  Uri? learn
  Uri? icon
  Str? isStr
  Str? kind
  Str? unit
  Str? enum
  Str? hisInterpolate
  Uri? obixCur
  Uri? obixWrite
  Uri? obixHis
  ObixLearnMore? more
}

**************************************************************************
** ObixLearnMore
**************************************************************************

internal abstract class ObixLearnMore
{
  new make(ObixLearnObj parent, Uri uri, ObixObj? arg)
  {
    this.parent = parent
    this.req = arg == null ? Contract.read : Contract.invoke
    this.uri = uri
    this.arg = arg
  }

  ObixClient client() { parent.parent.client }

  abstract Void onResult(ObixObj obj)

  ObixLearnObj parent
  Contract req
  Uri uri
  ObixObj? arg
}

**************************************************************************
** ObixNiagaraObj
**************************************************************************

internal class ObixNiagaraObj : ObixLearnObj
{
  new make(ObixLearn parent, ObixObj obj) : super(parent, obj)
  {
    // figure out if another request will give us more learn info
    if (more == null) more = ObixNiagaraMoreHisExt.check(this)
    if (more == null) more = ObixNiagaraMoreHisQuery.check(this)

    // see if we can parse facets
    facets := obj.get("facets", false)?.val as Str
    if (facets != null) parseFacets(facets)
  }

  private Void parseFacets(Str str)
  {
    try
    {
      // facets are formatted as key=t:val|key=t:val....
      map := Str:Str[:]
      str.split('|').each |tok|
      {
        eq := tok.index("=")
        key := tok[0..<eq]
        val := tok[eq+3..-1]
        map[key] = val
      }

      // map trueText,falseText as enum range
      trueText := map["trueText"]
      falseText := map["falseText"]
      if (trueText != null && falseText != null)
      {
        trueText = unescapeName(trueText).replace(",", ".")
        falseText = unescapeName(falseText).replace(",", ".")
        this.enum = "$falseText,$trueText"
        return
      }

      // map range as enum range is formatted as {key=0,key=1}
      range := map["range"]
      if (range != null)
      {
        names := Str[,]
        range[1..-2].split(',').each |pair|
        {
          name := pair[0..<pair.index("=")].trim
          name = unescapeName(name).replace(",", ".")
          names.add(name)
        }
        this.enum = names.join(",")
        return
      }
    }
    catch (Err e) {}
  }

  override Str unescapeName(Str name)
  {
    try
    {
      s := StrBuf()
      for (i:=0; i<name.size; ++i)
      {
        ch := name[i]
        if (ch == '_') { s.addChar(' '); continue }
        if (ch != '$') { s.addChar(ch); continue }
        ch = name[++i].fromDigit(16).shiftl(4) + name[++i].fromDigit(16)
        s.addChar(ch)
      }
      return s.toStr
    }
    catch (Err e) { e.trace; return name }
  }
}

**************************************************************************
** ObixNiagaraMoreHisExt
**************************************************************************

//
// In the case of a Niagara point with HistoryExt we can read the
// extensions historyConfig to get the id.  We can also check the ext
// type to infer whether we have a cov or interval collector
//
internal class ObixNiagaraMoreHisExt : ObixLearnMore
{
  static ObixLearnMore? check(ObixNiagaraObj p)
  {
    // we are looking for an obix:Point which has a HistoryExt
    if (!p.isPoint) return null
    hisExt := p.obj.list.find |child| { child.contract.toStr.contains("HistoryExt") }
    if (hisExt == null) return null

    // if the HistoryExt contract contains "Cov" then assume COV collection
    if (hisExt.contract.toStr.contains("Cov"))
      p.hisInterpolate = "cov"

    // we are looking for a historyConfig/ object
    return make(p, p.uri + hisExt.href + `historyConfig/`)
  }

  override Void onResult(ObixObj res)
  {
    // the "id" field defines the a string value like "/station/name"
    idObj := res.get("id", false)
    if (idObj == null || idObj.isNull || idObj.val isnot Str) return
    Str id := idObj.val
    parent.obixHis = client.lobbyUri.plus("histories${id}/".toUri).relToAuth
  }

  new make(ObixNiagaraObj p, Uri u) : super(p, u, null) {}
}

**************************************************************************
** ObixNiagaraMoreHisQuery
**************************************************************************

//
// In the case of a Niagara history point we have to do actually do
// a query of the history data to get kind and unit
//
internal class ObixNiagaraMoreHisQuery : ObixLearnMore
{
  static ObixLearnMore? check(ObixNiagaraObj p)
  {
    // we only care about Niagara obix:History without kind
    if (!p.isHistory) return null
    if (p.kind != null) return null

    // skip audit/log histories which sometimes cause Niagara
    // to fail anyways with an incomplete XML response
    if (p.uri.name == "AuditHistory") return null
    if (p.uri.name == "LogHistory") return null

    // get query op URI
    query := p.obj.get("query", false)?.href
    if (query == null) return null

    // get history's last timestamp
    end := p.obj.get("start", false)?.val as DateTime
    if (end == null) return null

    // build up history query to read just last timestamp
    arg := ObixObj
    {
      contract = historyFilterContract
      ObixObj { name="limit"; val = 1 },
    }

    // we have a more operation to perform!
    return make(p, query, arg)
  }

  static const Contract historyFilterContract := Contract("obix:HistoryFilter")

  override Void onResult(ObixObj res)
  {
    /*
    <obj href='/obix/histories/station/foo/~historyQuery/' is='obix:HistoryQueryOut'>
     ...
     <obj href='#RecordDef' is='obix:HistoryRecord'>
      <abstime name='timestamp' isNull='true' tz='America/Los_Angeles'/>
      <real name='value' val='0.0' unit='obix:units/cubic_feet_per_minute'/>
     </obj>
    </obj>
    */
    proto := res.last?.get("value", false)
    if (proto == null) return
    parent.unit = proto.unit?.symbol
    parent.kind = parent.toKind(proto)
  }

  new make(ObixNiagaraObj p, Uri u, ObixObj a) : super(p, u, a) {}
}

