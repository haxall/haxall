//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 13  Brian Frank  Creation
//

using auth
using xeto
using haystack
using web
using xml
using hx
using hxConn

**
** EnergyStarClient
**
class EnergyStarClient
{
  static new makeForConn(Proj proj, Dict rec)
  {
    if (rec.missing("energyStarConn")) throw Err("Not energyStarConn: $rec.dis")
    pass := proj.db.passwords.get(rec->id.toStr) ?: ""
    return make(rec, pass, proj.ext("energyStar").log)
  }

  new makeNoAuth(Log log := Log.get("energyStar"))
  {
    this.rec = Etc.emptyDict
    this.username = ""
    this.log = log
    this.uriBase = uriTest
  }

  private new make(Dict rec, Str password, Log log := Log.get("energyStar"))
  {
    this.rec = rec
    this.username = rec["username"] ?: ""
    this.accountIdRef = rec["accountId"]
    this.authHeader = "Basic " + "$username:$password".toBuf.toBase64
    this.log = log
    this.uriBase = (rec["uri"] as Uri ?: uriLive).plusSlash
    // log.level = LogLevel.debug
  }

  Str accountId()
  {
    if (accountIdRef == null) ping
    return accountIdRef
  }

  once Str[] customerIds()
  {
    s := rec["energyStarCustomerIds"] as Str
    if (s != null) return s.split(',')
    return [accountId]
  }

  Dict ping()
  {
    // ping the account info
    xml     := call("GET", `account`)
    id      := xml.elem("id").text.val
    contact := xml.elem("contact")
    name    := contact.elem("firstName").text.val + " " + contact.elem("lastName").text.val
    org     := xml.elem("organization").get("name")

    // map about to ping tags
    tags := Str:Obj[:]
    tags["accountId"]   = this.accountIdRef = id
    tags["accountName"] = name
    tags["accountOrg"]  = org
    return Etc.makeDict(tags)
  }

  XElem call(Str method, Uri uri, Str? reqXml := null, [Str:Str]? reqHeaders := null)
  {
    if (uri.isPathAbs) throw ArgErr("uri is abs: $uri")
    c := WebClient(uriBase + uri)
    c.followRedirects = false
    c.reqMethod = method
    if (authHeader != null) c.reqHeaders["Authorization"] = authHeader
    if (reqHeaders != null) c.reqHeaders.setAll(reqHeaders)
    if (reqXml == null)
    {
      // GET/DELETE
      c.writeReq
      c.readRes
    }
    else
    {
      if (log.isDebug)
      {
        echo("===== $c.reqUri")
        Env.cur.out.printLine("$reqXml")
      }
      // POST/PUT
      body := Buf().print(reqXml).flip
      c.reqHeaders["Content-Type"] = "application/xml; charset=utf-8"
      c.reqHeaders["Content-Length"] = body.size.toStr
      c.writeReq
      c.reqOut.writeBuf(body).close
      c.readRes
    }

    // authentication errors
    resXml := c.resIn.readAllStr
    if (c.resCode == 401) throw AuthErr("Invalid credentials for $username")
    if (c.resCode == 403) throw Err("Forbidden $method $c.reqUri")

    if (log.isDebug)
    {
      echo("===== $c.reqUri (raw)")
      echo(resXml)
      Env.cur.out.printLine
    }

    // parse XML response
    XElem? xml := null
    try
    {
      xml = XParser(resXml.in).parseDoc.root
      if (log.isDebug)
      {
        echo("===== $c.reqUri")
        xml.write(Env.cur.out)
        Env.cur.out.printLine
      }
    }
    catch (Err e)
    {
      echo("ERROR: Cannot parse energy star XML")
      echo(resXml)
      throw e
    }

    // handle error responses
    if (c.resCode / 100 != 2)
    {
      Str? msg
      try
        msg = xml.elem("errors").elem("error").toStr
      catch (Err e)
        msg = "$c.resCode $xml"
      throw EnergyStarErr(msg)
    }

    // good response
    return xml
  }

  **
  ** Read usage and invoke callback until it returns false
  **
  Void readUsage(Str meterId, |Str id, Date start, Date end, Number usage, Dict misc->Bool| f)
  {
    Uri? uri := `meter/$meterId/consumptionData`
    while (uri != null)
    {
      // make the RESt call
      resXml := call("GET", uri)

      // map XML to rows in our result grid
      XElem? links := null
      done := false
      resXml.elems.each |elem|
      {
        if (elem.name == "links") { links = elem; return }
        if (elem.name != "meterConsumption") return
        if (done) return
        id        := elem.elem("id").text.val
        startDate := Date.fromStr(elem.elem("startDate").text.val)
        endDate   := Date.fromStr(elem.elem("endDate").text.val)
        usage     := Number.fromStr(elem.elem("usage").text.val)
        misc      := [Str:Obj?][:]

        miscElem := elem.elem("cost", false)
        if (miscElem != null)
          misc["cost"] = Number.fromStr(miscElem.text.val)

        miscElem = elem.elem("RECOwnership", false)
        if (miscElem != null)
          misc["recownership"] = miscElem.text.val
        miscElem = elem.elem("energyExportedOffSite", false)
        if (miscElem != null)
          misc["energyExportedOffSite"] = Number.fromStr(miscElem.text.val)

        miscElem = elem.elem("demandTracking", false)
        if (miscElem != null)
        {
          demand := miscElem.elem("demand", false)
          if (demand != null) misc["demand"] = Number.fromStr(demand.text.val, false)
          demandCost := miscElem.elem("demandCost", false)
          if (demandCost != null) misc["demandCost"] = Number.fromStr(demandCost.text.val, false)
        }

        if (!f(id, startDate, endDate, usage, Etc.makeDict(misc))) done = true
      }
      if (done) break

      // check if we have more data left to read
      uri = null
      if (links != null)
      {
        link := links.elems.find |elem| { elem.get("linkDescription") == "next page" }
        if (link != null) uri = link.get("link")[1..-1].toUri
      }
    }
  }

  static const Uri uriTest := `https://portfoliomanager.energystar.gov/wstest/`
  static const Uri uriLive := `https://portfoliomanager.energystar.gov/ws`

  const Str username
  const Log log
  const Dict rec
  const Uri uriBase
  private const Str? authHeader
  private Str? accountIdRef
}

const class EnergyStarErr : Err
{
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

