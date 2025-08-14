//
// Copyright (c) 2013, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 13  Brian Frank  Creation
//

using xeto
using haystack
using web
using xml
using hx
using hxConn
using axon
using folio

**
** Energy Star library functions.
**
const class EnergyStarFuncs
{

//////////////////////////////////////////////////////////////////////////
// Connector
//////////////////////////////////////////////////////////////////////////

  **
  ** Asynchronously ping energy star connector to verify connectivity
  ** and account credentials.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarPing(Obj conn)
  {
    ConnFwFuncs.connPing(conn)
  }

//////////////////////////////////////////////////////////////////////////
// Property Management
//////////////////////////////////////////////////////////////////////////

  **
  ** Read properties as grid with following columns:
  **   - 'id': energy star property id str
  **   - 'dis': display name of the property
  **
  ** By default this returns the properties associated with the
  ** connector's accountId.  However if the connector defines the
  ** `energyStarCustomerIds` tag, then those account ids are
  ** used to populate the property list.
  **
  @Api @Axon
  static Grid energyStarPropertyList(Obj? conn)
  {
    cx := Context.cur
    c := toClient(cx, conn)

    // prepare grid
    cols := ["id", "dis"]
    rows := Obj?[,]

    // make call for each customer id
    c.customerIds.each |accountId|
    {
      resXml := c.call("GET", `account/$accountId/property/list`)
      resXml.elem("links").elems.each |elem|
      {
        if (elem.name != "link") return
        rows.add([elem.get("id"), elem.get("hint")])
      }
    }

    return Etc.makeListsGrid(null, cols, null, rows)
  }

  **
  ** Read the given property and return as Dict.
  ** See `doc#siteMapping`.
  **
  @Api @Axon
  static Dict energyStarPropertyRead(Obj? conn, Str propertyId)
  {
    // make REST call
    cx := Context.cur
    c := toClient(cx, conn)
    resXml := c.call("GET", `property/$propertyId`)

    // get some temp elements
    addr := resXml.elem("address")
    area := resXml.elem("grossFloorArea")

    // map XML to tags
    tags := Str:Obj?[:] { ordered = true }
    tags["dis"] = resXml.elem("name").text.val
    tags["primaryFunction"] =  resXml.elem("primaryFunction").text.val
    tags["numberOfBuildings"] =  Number(resXml.elem("numberOfBuildings").text.val.toInt)
    tags["yearBuilt"] =  Number(resXml.elem("yearBuilt").text.val.toInt)
    tags["constructionStatus"] = resXml.elem("constructionStatus").text.val
    tags["geoStreet"] =  addr.get("address1", false)
    tags["geoCity"] = addr.get("city", false)
    tags["geoState"] =  addr.get("state", false)
    tags["geoPostalCode"] =  addr.get("postalCode", false)
    tags["geoCountry"] =  addr.get("country", false)
    tags["area"] =  Number(area.elem("value").text.val.toInt, EnergyStarUtil.unitFromXml(area.get("units")))
    tags["occupancyPercentage"] =  Number(resXml.elem("occupancyPercentage").text.val.toInt, Unit("%"))
    if (resXml.elem("isFederalProperty").text.val.toBool) tags["isFederalProperty"] = Marker.val
    return Etc.makeDict(tags)
  }

  **
  ** Read a list of metrics for a specific property.  The month to be
  ** should be passed as month literal 'YYYY-MM' or any Date in that month.
  ** The metrics to be read as passed as Dict or markers and returned as
  ** a Dict with the resulting values.  If the metric is not available, then
  ** it is not included in the resulting Dict.
  **
  ** For list of metrics to query see
  ** [EnergyStar Docs]`http://portfoliomanager.energystar.gov/webservices/home/api/reporting/propertyMetrics/get`.
  **
  ** Example:
  **   energyStarPropertyMetrics(conn, "123", 2013-01, {score})  >>>  {score: 67}
  **
  @Api @Axon
  static Dict energyStarPropertyMetrics(Obj? conn, Str propertyId, Obj? month, Dict metrics)
  {
    // get date as month
    span := AxonFuncs.toDateSpan(month)
    if (!span.isDay && !span.isMonth) throw Err("Expected month as date or month, not $span")
    year := span.start.year
    mon := span.start.month.ordinal+1

    // make REST call
    cx := Context.cur
    c := toClient(cx, conn)
    headers := ["PM-Metrics": Etc.dictNames(metrics).join(",")]
    resXml := c.call("GET", `property/$propertyId/metrics?year=$year&month=$mon&measurementSystem=EPA`, null, headers)

    // parse response
    results := Str:Obj?[:]
    resXml.elems.each |elem|
    {
      if (elem.name != "metric") return
      name := elem.get("name")
      valElem := elem.elem("value")
      if (valElem.get("nil", false) != null) return
      valStr := valElem.text?.val ?: valElem.toStr
      val := Number.fromStr(valStr, false) ?: valStr
      uom := elem.get("uom", false)
      if (uom != null)
      {
        try
        {
          unit := EnergyStarUtil.unitFromXml(elem.get("uom"))
          val   = Number.make(((Number)val).toFloat, unit)
        }
        catch (Err ignore) { /* just make unitless metric */ }
      }
      results[name] = val
    }

    return Etc.makeDict(results)
  }

  **
  ** Create or update a property in Portfolio Manager from a local site record.
  ** If the rec has `energyStarSite` tag then it is the property id to update.
  ** Otherwise a new property is created under the connector's account
  ** and the `energyStarSite` tag is added to the site record.
  ** See `doc#siteMapping`.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarPropertyPush(Obj? conn, Obj site)
  {
    cx := Context.cur
    c := toClient(cx, conn)

    // get tags from site rec
    s := Etc.toRec(site)
    propId            := s["energyStarSite"] as Str
    primaryFunction   := (Str)s->primaryFunction
    geoStreet         := (Str)s->geoStreet
    geoCity           := (Str)s->geoCity
    geoPostalCode     := (Str)s->geoPostalCode
    geoState          := (Str)s->geoState
    geoCountry        := (Str)s->geoCountry
    yearBuilt         := (Number)s->yearBuilt
    ctorStatus        := s["constructionStatus"] ?: "Existing"
    area              := (Number)s->area
    areaUnits         := EnergyStarUtil.unitToXml(area.unit ?: throw Err("area missing unit"))
    occPercent        := EnergyStarUtil.toOccupancyPercentage(s["occupancyPercentage"])
    isFederalProperty := s.has("isFederalProperty")

    // map to XML request
    reqXml :=
      """<property>
           <name>$s.dis.toXml</name>
           <primaryFunction>$primaryFunction.toXml</primaryFunction>
           <address address1='$geoStreet.toXml'
                    city='$geoCity.toXml'
                    postalCode='$geoPostalCode.toXml'
                    state='$geoState'
                    country='$geoCountry'/>
           <yearBuilt>$yearBuilt.toInt</yearBuilt>
           <numberOfBuildings>1</numberOfBuildings>
           <constructionStatus>$ctorStatus</constructionStatus>
           <grossFloorArea temporary="false" units="$areaUnits">
             <value>$area.toInt</value>
           </grossFloorArea>
           <occupancyPercentage>$occPercent</occupancyPercentage>
           <isFederalProperty>$isFederalProperty</isFederalProperty>
         </property>"""

    if (propId == null)
    {
      resXml := c.call("POST", `account/$c.accountId/property`, reqXml)
      propId = resToId(resXml)
      cx.proj.commit(Diff(s, ["energyStarSite":propId], Diff.force))
      return "Created property in Portfolio Manager: ${propId}"
    }
    else
    {
      resXml := c.call("PUT", `property/$propId`, reqXml)
      return "Updated property in Portfolio Manager: ${propId}"
    }
  }

  **
  ** Create or update a local site record from a property in Portfolio Manager.
  ** If an existing rec has `energyStarSite` tag then it is the site to update.
  ** Otherwise create a new site record.  Note if there is navigation recs
  ** above the site level, then you must manually add the appropiate ref tags.
  ** If creating a new record, not all the tags may be get automatically created,
  ** so check the record in the BuilderApp.
  ** See `doc#siteMapping`.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarPropertyPull(Obj? conn, Str propertyId)
  {
    cx := Context.cur
    c := toClient(cx, conn)

    remote := energyStarPropertyRead(conn, propertyId)

    tags := Str:Obj[:]
    remote.each |v, n| { tags[n] = v }
    if (remote.missing("isFederalProperty")) tags["isFederalProperty"] = Remove.val

    rec := cx.proj.read("site and energyStarSite==$propertyId.toCode", false)
    if (rec == null)
    {
      tags["energyStarConnRef"] = c.rec.id
      tags["energyStarSite"] = propertyId
      tags["site"] = Marker.val
      tags["tz"]   = TimeZone.cur.name

      cx.proj.commit(Diff.makeAdd(tags))
      return "Created site for Energy Star property: ${propertyId}"
    }
    else
    {
      cx.proj.commit(Diff(rec, tags))
      return "Updated site ${rec.dis} from Energy Star property: ${propertyId}"
    }
  }

  **
  ** Delete the property identified by the given property id string from
  ** the energy star Portfolio Manager.
  **
  ** Any site recs with matching 'energyStarSite' value also have have
  ** that tag removed.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarPropertyDelete(Obj? conn, Str propertyId)
  {
    cx := Context.cur

    // delete from energy star
    c := toClient(cx, conn)
    resXml := c.call("DELETE", `property/$propertyId`)

    // update any site recs that have that id
    cx.proj.readAll("site and energyStarSite==$propertyId.toCode").each |site|
    {
      cx.proj.commit(Diff(site, ["energyStarSite":Remove.val], Diff.force))
    }

    return "Removed property ${propertyId} from Energy Star Portfolio Manager"
  }

//////////////////////////////////////////////////////////////////////////
// Customers
//////////////////////////////////////////////////////////////////////////

  **
  ** Read list of customers that you are connected with as grid
  ** with following columns:
  **   - 'id': energy star customer id str
  **   - 'dis': display name of the customer
  **
  @Api @Axon
  static Grid energyStarCustomerList(Obj? conn)
  {
    cx := Context.cur
    c := toClient(cx, conn)

    // prepare grid
    cols := ["id", "dis"]
    rows := Obj?[,]

    // make call for each customer id
    resXml := c.call("GET", `customer/list`)
    resXml.elem("links").elems.each |elem|
    {
      if (elem.name != "link") return
      rows.add([elem.get("id"), elem.get("hint")])
    }

    return Etc.makeListsGrid(null, cols, null, rows)
  }

//////////////////////////////////////////////////////////////////////////
// Meter Management
//////////////////////////////////////////////////////////////////////////

  **
  ** Read meters for given property as grid with following columns:
  **   - 'id': energy star meter id str
  **   - 'dis': display name of the meter
  **   - 'association': meter/property association formatted
  **     as "meter: representation" such as "energyMeter: Whole Property".
  **     If this cell is null, then an association has not been made yet.
  **
  @Api @Axon
  static Grid energyStarMeterList(Obj? conn, Str propertyId)
  {
    cx := Context.cur
    c := toClient(cx, conn)

    // make 1st REST Call to get property/meter associations
    resXml := c.call("GET", `association/property/$propertyId/meter`)
    assocById := Str:Str[:]
    representationById := Str:Str[:]
    resXml.elems.each |elem|
    {
      if (!elem.name.endsWith("Association")) return
      meterType := elem.name[0..-12]
      val := "$meterType"
      propRep := elem.elem("propertyRepresentation", false)
      if (propRep != null)
      {
        representation := propRep.elem("propertyRepresentationType").text.val
        val = "${val}: ${representation}"
      }
      elem.elem("meters").elems.each |meterElem|
      {
        meterId := meterElem.text.val
        assocById[meterId] = val
      }
    }

    // make REST Call to list the meters
    resXml = c.call("GET", `property/$propertyId/meter/list`)

    // map link elements to grid rows
    cols := ["id", "dis", "association"]
    rows := Obj?[,]
    resXml.elem("links").elems.each |elem|
    {
      if (elem.name != "link") return
      meterId := elem.get("id")
      hint := elem.get("hint")
      assoc := assocById[meterId]
      rows.add([meterId, hint, assoc])
    }
    return Etc.makeListsGrid(null, cols, null, rows)
  }

  **
  ** Read the given meter and return as Dict.
  ** See `doc#meterMapping`.
  **
  @Api @Axon
  static Dict energyStarMeterRead(Obj? conn, Str meterId)
  {
    // make REST call
    cx := Context.cur
    c := toClient(cx, conn)
    resXml := c.call("GET", `meter/$meterId`)

    // temp elements
    inactiveDate := resXml.elem("inactiveDate", false)
    metered := resXml.elem("metered").text.val.toBool
    inUse := resXml.elem("inUse").text.val.toBool

    // map XML to tags
    tags := Str:Obj?[:] { ordered = true }
    tags["dis"]  = resXml.elem("name").text.val
    tags["energyStarMeterType"] = resXml.elem("type").text.val
    tags["unit"] = EnergyStarUtil.unitFromXml(resXml.elem("unitOfMeasure").text.val).symbol
    tags["firstBillDate"] = Date(resXml.elem("firstBillDate").text.val)
    if (inactiveDate != null) tags["inactiveDate"] = Date(inactiveDate.text.val)
    if (metered) tags["metered"] = Marker.val
    if (inUse)   tags["inUse"] = Marker.val
    return Etc.makeDict(tags)
  }

  **
  ** Create or update a meter in Portfolio Manager from a local meter point record.
  ** If the rec has `energyStarMeter` tag then it is the meter id to update.
  ** Otherwise create a new meter and add `energyStarMeter` tag to the site record.
  ** See `doc#meterMapping`.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarMeterPush(Obj? conn, Obj point)
  {
    cx := Context.cur

    c := toClient(cx, conn)

    // read fresh copy of meter point
    pt := Etc.toRec(point)

    // read its site and ensure it has energyStarSite
    propertyId := pointToPropertyId(cx.proj, pt)

    // get tags from rec
    meterId       := pt["energyStarMeter"] as Str
    type          := EnergyStarUtil.pointToMeterType(pt)
    unitXml       := EnergyStarUtil.unitToXml(Unit.fromStr(pt->unit))
    firstBillDate := pt["firstBillDate"] as Date ?: throw Err("Must add firstBillDate to point")

    // map to XML request
    reqXml :=
      """<meter>
           <name>$pt.dis.toXml</name>
           <type>$type</type>
           <unitOfMeasure>$unitXml</unitOfMeasure>
           <metered>true</metered>
           <firstBillDate>$firstBillDate</firstBillDate>
           <inUse>true</inUse>
         </meter>"""

    if (meterId == null)
    {
      resXml := c.call("POST", `property/$propertyId/meter`, reqXml)
      meterId = resToId(resXml)
      cx.proj.commit(Diff(pt, ["energyStarMeter":meterId, "energyStarConnRef": c.rec.id], Diff.force))
      return "Created meter in Portfolio Manager: ${meterId}"
    }
    else
    {
      resXml := c.call("PUT", `meter/$meterId`, reqXml)
      return "Updated meter in Portfolio Manager: ${meterId}"
    }
  }

  **
  ** Create or update a local meter point record from a meter in Portfolio Manager.
  ** If an existing rec has `energyStarMeter` tag then it is the point to update.
  ** If the point has to be created, then it is always placed under the main
  ** electrict meter queried by 'elecMeter and siteMeter'.  Or if a main meter is
  ** not found, one is automatically created.  The point many not have all its tags
  ** automatically created, so check the record in the BuilderApp.
  ** See `doc#meterMapping`.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarMeterPull(Obj? conn, Obj site, Str meterId)
  {
    cx := Context.cur
    c := toClient(cx, conn)
    siteRec := Etc.toRec(site)

    remote := energyStarMeterRead(conn, meterId)

    tags := Str:Obj?[:]
    remote.each |v, n| { if (n != "dis") tags[n] = v }
    if (remote.missing("metered")) tags["metered"] = Remove.val
    if (remote.missing("inUse")) tags["inUse"] = Remove.val

    rec := cx.proj.read("point and energyStarMeter==$meterId.toCode", false)
    if (rec == null)
    {
      m := Marker.val

      // get or create elecMeter
      elecMeter := cx.proj.read("(elecMeter or (elec and meter)) and siteRef==$siteRec.id.toCode", false)
      if (elecMeter == null)
      {
        meterTags :=
        [
          "equip": Marker.val,
          "elec": Marker.val,
          "meter": Marker.val,
          "siteMeter": Marker.val,
          "siteRef": siteRec.id,
          "navName": "ElecMeter",
          "disMacro": "\$siteRef \$navName",
        ]
        proto := cx.defs.proto(siteRec, Etc.makeDict(["elec":m, "equip":m, "meter":m]))
        proto.each |val, name| {
          if (val is Ref) meterTags[name] = val
        }
        elecMeter = cx.proj.commit(Diff.makeAdd(meterTags)).newRec
      }

      tags["energyStarConnRef"] = c.rec.id
      tags["energyStarMeter"] = meterId
      tags["point"]     = Marker.val
      tags["his"]       = Marker.val
      tags["sensor"]    = Marker.val
      tags["kind"]      = "Number"
      tags["navName"]   = remote.dis
      tags["disMacro"]  = "\$equipRef \$navName"
      tags["equipRef"]  = elecMeter.id
      tags["tz"]        = siteRec["tz"]
      proto := cx.defs.proto(elecMeter, Etc.makeDict(["point":m, "sensor":m]))
      proto.each |val, name| {
        if (val is Ref) tags[name] = val
      }
      cx.proj.commit(Diff.makeAdd(tags))
      return "Created meter point for Portfolio Manager meter: ${meterId}"
    }
    else
    {
      cx.proj.commit(Diff(rec, tags))
      return "Updated meter point for Portfolio Manager meter: ${meterId}"
    }
  }

  **
  ** Delete the meter identified by the given meter id string from
  ** the energy star Portfolio Manager.
  **
  ** Any recs with matching 'energyStarMeter' value also have have
  ** that tag removed.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarMeterDelete(Obj? conn, Str meterId)
  {
    cx := Context.cur

    // delete from energy star
    c := toClient(cx, conn)
    resXml := c.call("DELETE", `meter/$meterId`)

    // update any meter recs that have that id
    cx.proj.readAll("point and energyStarMeter==$meterId.toCode").each |rec|
    {
      cx.proj.commit(Diff(rec, ["energyStarMeter":Remove.val], Diff.force))
    }

    return "Removed meter ${meterId} from Portfolio Manager"
  }

//////////////////////////////////////////////////////////////////////////
// Associations
//////////////////////////////////////////////////////////////////////////

  **
  ** This function recreates the list of property/meter associations in
  ** Energy Star.  The site must be an id or record for a site which has
  ** been mapped to Energy Star with an `energyStarSite` tag.  Associations
  ** are created for every meter point within the site which has been
  ** mapped with the `energyStarMeter` tag.  All associations are currently
  ** mapped as "Whole Property'.  See `doc#associations`.
  **
  @Api @Axon
  static Obj energyStarPropertyAssociationsPush(Obj? conn, Obj site)
  {
    // lookup site and gets it energy star propertyId
    cx := Context.cur
    rec := Etc.toRec(site)
    if (rec.missing("site")) throw Err("Not site rec: $rec.dis")
    propertyId := rec["energyStarSite"] as Str ?: throw Err("Site missing energyStarSite tag: $rec.dis")

    // get the meter points in this site
    meterPoints := cx.proj.readAll("point and energyStarMeter and siteRef==$rec.id.toCode")
    energyMeters := StrBuf()
    waterMeters := StrBuf()
    meterPoints.each |meterPoint|
    {
      meterId := (Str)meterPoint->energyStarMeter
      meterType := EnergyStarUtil.pointToMeterType(meterPoint)
      assocType := EnergyStarUtil.meterTypeToAssocType(meterType)
      xml := "      <meterId>$meterId</meterId>\n"
      if (assocType == AssocType.energy)
        energyMeters.add(xml)
      else if (assocType == AssocType.water)
        waterMeters.add(xml)
      else throw Err("Unsupported meter type: ${meterType}")
    }

    // build request XML
    reqXml :=
     """<meterPropertyAssociationList>
          <energyMeterAssociation>
            <meters>
        $energyMeters
            </meters>
           <propertyRepresentation>
            <propertyRepresentationType>Whole Property</propertyRepresentationType>
           </propertyRepresentation>
          </energyMeterAssociation>
          <waterMeterAssociation>
            <meters>
        $waterMeters
            </meters>
            <propertyRepresentation>
              <propertyRepresentationType>Whole Property</propertyRepresentationType>
            </propertyRepresentation>
          </waterMeterAssociation>
        </meterPropertyAssociationList>"""

    // make REST Call
    c := toClient(cx, conn)
    resXml := c.call("POST", `association/property/$propertyId/meter`, reqXml)

    // map link elements to grid rows
    return resXml
  }

//////////////////////////////////////////////////////////////////////////
// Usage
//////////////////////////////////////////////////////////////////////////

  **
  ** Read consumption data for given meter.  Return grid with cols:
  **   - id: Str identifier for the consumption data item
  **   - startDate: first Date of consumption
  **   - endDate: last Date of consumption
  **   - usage: Number for usage of date range
  **   - recownership (optional): If present, the Str REC ownership status.
  **   - energyExportedOffSite (optional): If present, the Number for the
  **     amount of energy exported off site.
  **
  ** It is expected for the EnergyStar web service to give us pages of
  ** data from newest dates down to oldest dates.  We continue to read
  ** pages of data until no data is left or we hit our limit for rows of
  ** usage data.
  **
  @Api @Axon
  static Grid energyStarUsageRead(Obj? conn, Str meterId, Number? limit := Number(100))
  {
    cx    := Context.cur
    meter := cx.proj.read("energyStarMeter==${meterId.toCode}", false)
    c     := toClient(cx, conn)
    max   := limit == null ? Int.maxVal : limit.toInt
    count := 0
    isSiteSolar := "Electric on Site Solar" == meter?.get("energyStarMeterType")

    // map link elements to grid rows
    gb := GridBuilder()
    gb.addCol("id")
      .addCol("startDate")
      .addCol("endDate")
      .addCol("usage")
      .addCol("cost")
    if (isSiteSolar)
    {
      gb.addCol("recownership")
        .addCol("energyExportedOffSite")
    }
    gb.addCol("demand").addCol("demandCost")
    c.readUsage(meterId) |id, startDate, endDate, usage, misc|
    {
      row := [id, startDate, endDate, usage, misc["cost"]]
      if (isSiteSolar)
        row.add(misc["recownership"]).add(misc["energyExportedOffSite"])

      // demand tracking
      row.add(misc["demand"]).add(misc["demandCost"])

      gb.addRow(row)
      count++
      return count < max
    }
    return gb.toGrid
  }

  **
  ** Write consumption data to portfolio manager for given meter.
  ** The usage must be grid with cols:
  **   - startDate: first Date of consumption
  **   - endDate: last Date of consumption (or if missing, startDate is assumed)
  **   - usage: Number for usage of date range
  **   - cost: (optional) Number for cost of usage
  **   - estimatedValue: (optional) Marker or Bool indicating if the value is estimated.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarUsageWrite(Obj? conn, Str meterId, Grid usage)
  {
    // read energy star meter
    cx    := Context.cur
    meter := cx.proj.read("energyStarMeter==${meterId.toCode}", false) ?: Etc.emptyDict
    meterType := meter.get("energyStarMeterType")

    // get xml based on meter type
    isWaste := EnergyStarUtil.meterTypeToAssocType(meterType) == AssocType.waste
    reqXml  := isWaste ? wasteUsageXml(meter, usage) : consumptionUsageXml(meter, usage)

    // make REST Call
    c      := toClient(cx, conn)
    uri    := `meter/${meterId}/`.plus(isWaste ? `wasteData` : `consumptionData`)
    resXml := c.call("POST", uri, reqXml)

    return "written"
  }

  private static Str consumptionUsageXml(Dict meter, Grid usage)
  {
    isSiteSolar := "Electric on Site Solar" == meter.get("energyStarMeterType")

    reqXml := StrBuf()
    reqXml.add("<meterData>\n")
    usage.each |row|
    {
      val       := (Number)row->usage
      startDate := (Date)row->startDate
      endDate   := row["endDate"] as Date ?: startDate
      estimated := false
      if (row.has("estimatedValue"))
      {
        v := row["estimatedValue"]
        estimated = v is Marker || v == true
      }
      reqXml.add("<meterConsumption estimatedValue=\"${estimated}\">\n")
      reqXml.add(" <usage>").add(val.toFloat.toDecimal).add("</usage>\n")
      reqXml.add(" <startDate>").add(startDate).add("</startDate>\n")
      reqXml.add(" <endDate>").add(endDate).add("</endDate>\n")
      if (row.has("cost"))
      {
        reqXml.add(" <cost>").add(row["cost"]->toFloat->toDecimal).add("</cost>\n")
      }
      if (isSiteSolar)
      {
        // Electric On Site Solar meters require these tags
        offsite := row.get("energyExportedOffSite") ?: meter["energyExportedOffSite"]
        reqXml.add(" <energyExportedOffSite>").add(offsite?->toFloat).add("</energyExportedOffSite>\n")
      }

      demand := row["demand"]
      demandCost := row["demandCost"]
      if (demand != null || demandCost != null)
      {
        reqXml.add(" <demandTracking>\n")
        if (demand != null)
          reqXml.add("  <demand>").add(((Number)demand).toFloat.toDecimal.toLocale("#.##")).add("</demand>\n")
        if (demandCost != null)
          reqXml.add("  <demandCost>").add(((Number)demandCost).toFloat.toDecimal).add("</demandCost>\n")
        reqXml.add(" </demandTracking>\n")
      }
      reqXml.add("</meterConsumption>\n")
    }
    reqXml.add("</meterData>\n")
    return reqXml.toStr
  }

  private static Str wasteUsageXml(Dict meter, Grid usage)
  {
    reqXml := StrBuf()
    reqXml.add("<wasteDataList>\n")
    usage.each |row|
    {
      reqXml.add("<wasteData>\n")
      stdUsageXml(reqXml, row)
      disposal := toDisposalDestination(row, meter)
      if (!disposal.isEmpty)
      {
        reqXml.add("<disposalDestination>")
        disposal.each |v, k|
        {
          reqXml.add("<$k>${v->toFloat->toDecimal}</$k>\n")
        }
        reqXml.add("</disposalDestination>")
      }
      reqXml.add("</wasteData>\n")
    }
    reqXml.add("</wasteDataList>\n")
    return reqXml.toStr
  }

  private static Dict toDisposalDestination(Dict row, Dict meter)
  {
    m := Str:Obj[:]
    keys := ["energyStarLandfillPercentage",
             "energyStarIncinerationPercentage",
             "energyStarWasteToEnergyPercentage",
             "energyStarUnknownDestPercentage",]
    keys.each |key|
    {
      v := row[key]
      if (v == null) v = meter[key]
      if (v != null) m[key["energyStar".size..-1].decapitalize] = v
    }

    return Etc.makeDict(m)
  }

  private static Void stdUsageXml(StrBuf reqXml, Dict row)
  {
    val       := (Number)row->usage
    startDate := (Date)row->startDate
    endDate   := row["endDate"] as Date ?: startDate
    reqXml.add(  "<startDate>").add(startDate).add("</startDate>\n")
    reqXml.add(  "<endDate>").add(endDate).add("</endDate>\n")
    reqXml.add("  <quantity>").add(val.toFloat.toDecimal).add("</quantity>\n")
    if (row.has("cost"))
    {
      reqXml.add("  <cost>").add(row["cost"]->toFloat->toDecimal).add("</cost>\n")
    }
  }

  **
  ** Delete the given usage item from portfolio manager
  **
  @Api @Axon { admin = true }
  static Obj? energyStarUsageDelete(Obj? conn, Str consumptionDataId)
  {
    cx := Context.cur
    c := toClient(cx, conn)
    resXml := c.call("DELETE", `consumptionData/$consumptionDataId`)
    return "deleted"
  }

  ** Write onsite green power renewable details.
  ** See `https://portfoliomanager.energystar.gov/webservices/home/api/meter/onsite/post`
  ** for details on this API request.
  **   - 'meterId': The meter id of the meter to write details for
  **   - 'detail': A Dict containing the details to write. The structure of this
  **   Dict must adhere to the 'onsiteRenewableDetail.xsd' schema specified by
  **   the API in the link above. It is your responsibility to construct a details
  **   that meets the semantic constraints of the api - this func does constraint
  **   checking.
  **
  ** pre>
  ** detail: {currentAsOf: 2024-12-06, energyUsedOnsite: {recOwnership: "Owned"}, energyExportedToGrid: {recOwnership: "Owned"}}
  ** energyStarOnsiteRenewableDetailWrite(conn, meterId, detail)
  ** <pre
  @Api @Axon { admin = true }
  static Obj? energyStarOnsiteRenewableDetailWrite(Obj? conn, Str meterId, Dict detail)
  {
    cx := Context.cur
    c := toClient(cx, conn)
    reqXml := StrBuf().add("<onsiteRenewableDetail>\n")
    reqXml.add("  <currentAsOf>${detail->currentAsOf}</currentAsOf>\n")
    onsiteUsageDetail(reqXml, "energyUsedOnsite", detail)
    onsiteUsageDetail(reqXml, "energyExportedToGrid", detail)
    reqXml.add("</onsiteRenewableDetail>")
    resXml := c.call("POST", `meter/${meterId}/onsiteRenewableDetails`, reqXml.toStr)
    return reqXml.toStr
  }

  private static Void onsiteUsageDetail(StrBuf reqXml, Str tag, Dict detail)
  {
    m := detail[tag] as Dict
    if (m == null) return
    genLoc    := m["generationLocation"] as Dict
    gpType    := m["greenPowerType"]
    vintage   := m["meetVintageRequirement"]
    certified := m["certifiedByGreene"]
    tab       := "    "
    reqXml.add("  <${tag}>\n")
    reqXml.add("${tab}<recOwnership>${m->recOwnership}</recOwnership>\n")
    if (genLoc != null)
    {
      // this xml schema type should only have one key/value pair (it's a choice)
      reqXml.add("${tab}<generationLocation>")
      genLoc.each |val, name| { reqXml.add("<${name}>${val}</${name}>") }
      reqXml.add("</generationLocation>\n")
    }
    if (gpType != null)    reqXml.add("${tab}<greenPowerType>${gpType}</greenPowerType>\n")
    if (vintage != null)   reqXml.add("${tab}<meetVintageRequirement>${vintage}</meetVintageRequirement>\n")
    if (certified != null) reqXml.add("${tab}<certifiedByGreene>${certified}</certifiedByGreene>\n")
    reqXml.add("  </${tag}>\n")
  }

//////////////////////////////////////////////////////////////////////////
// His Sync
//////////////////////////////////////////////////////////////////////////

  **
  ** Pull energy star usage into the given mapped meter points history.
  ** The proxies may be any set of points
  ** accepted by `toRecList`.
  **
  ** Each point is required:
  **   - define `energyStarConnRef` tag for connector to use
  **   - define `energyStarMeter` for which meter it is mapped to
  **   - must be a point with historized consumption values
  **   - point's site must define `energyStarSite` tag
  **
  ** The EnergyStar usage must provide daily values which are mapped
  ** to midnight of the starting date.
  **
  @Api @Axon { admin = true }
  static Obj? energyStarHisPull(Obj proxies, Obj? range)
  {
    cx := Context.cur
    // if (Context.cur.missingAnalytics) throw LicensingErr.missingAnalytics
    recs := Etc.toRecs(proxies)
    return ConnFwFuncs.connSyncHis(recs, range)
  }

  **
  ** Push the daily rollup consumption of mapped meter points to
  ** portfolio manager.  The proxies may be any set of points
  ** accepted by `toRecList`.
  **
  ** Each point is required:
  **   - define `energyStarConnRef` tag for connector to use
  **   - define `energyStarMeter` for which meter it is mapped to
  **   - must be a point with historized consumption values
  **   - point's site must define `energyStarSite` tag
  **
  ** If the range is null, then we perform a read using `energyStarUsageRead`
  ** to find the last endDate written.  Then we assume a range of endDate+1day
  ** to yesterday.  This guarantees that we are only pushing newer data to
  ** portfolio manager.
  **
  ** The usage to push is calcualted by perform a daily rollup on the history
  ** using the `sum` function:
  **
  **   read(proxy).hisRead(range).hisClip.hisRollup(sum, 1day)
  **
  @Api @Axon { admin = true }
  static Obj? energyStarHisPush(Obj proxies, Obj? range)
  {
    // TODO: clean this up now that we are using eval to call his funcs
    cx := Context.cur
    // if (Context.cur.missingAnalytics) throw LicensingErr.missingAnalytics

    recs := Etc.toRecs(proxies)
    recs.each |rec|
    {
      // licensing check/meter id mapping
      meterId := pointToMeterId(cx.proj, rec)

      // map to connector and EnergyStarClient
      connRef := (Ref)rec->energyStarConnRef

      // if range is null, then query energy star for last timestamp
      hisReadRange := range
      if (hisReadRange == null)
      {
        newestUsage := energyStarUsageRead(connRef, meterId, Number.one).first
        if (newestUsage == null) hisReadRange = DateSpan.thisWeek
        else
        {
          start := (Date)newestUsage->endDate + 1day
          end   := Date.today - 1day
          if (start > end) return
          hisReadRange = DateSpan(start, end)
        }
      }

      // read history data for range
      span := Etc.toSpan(hisReadRange, null, cx)
      his := (Grid)cx.eval("hisRead(${rec.id.toCode}, ${span.toCode}).hisClip.hisRollup(sum, 1day)")
      // his := HisLib.hisRead(rec, hisReadRange, opts)
      // his = HisLib.hisRollup(his, fold, interval)

      // turn into usage write grid
      writeGrid := GridBuilder().addCol("startDate").addCol("usage")
      his.each |item|
      {
        DateTime ts := item->ts
        val := item["v0"] as Number
        if (val == null) return
        writeGrid.addRow([ts.date, val])
      }
      energyStarUsageWrite(connRef, meterId, writeGrid.toGrid)
    }

    return "pushed $recs.size"
  }

//////////////////////////////////////////////////////////////////////////
// Account Management
//////////////////////////////////////////////////////////////////////////

  **
  ** Create an account from Dict with following tags:
  **   - 'username'
  **   - 'password'
  **   - 'firstName'
  **   - 'lastName'
  **   - 'email'
  **   - 'org'
  **
  ** Return new account id
  **
  @NoDoc @Api @Axon
  static Str energyStarCreateAccount(Dict info)
  {
    // get input tags
    username  := (Str)info->username
    password  := (Str)info->password
    firstName := (Str)info->firstName
    lastName  := (Str)info->lastName
    email     := (Str)info->email
    org       := (Str)info->org
    random    := Buf.random(32).toBase64

    // map to XML request
    reqXml :=
       """<account>
            <username>$username.toXml</username>
            <password>$password.toXml</password>
            <webserviceUser>true</webserviceUser>
            <searchable>false</searchable>
            <contact>
                <firstName>$firstName</firstName>
                <lastName>$lastName</lastName>
                <email>$email.toXml</email>
                <phone>123-456-7890</phone>
                <address address1='100 Too Many' city='Required Fields' state='VA' postalCode='22201' country='US'/>
                <jobTitle>Too Many Required Fields</jobTitle>
            </contact>
            <organization name="$org.toXml">
                <primaryBusiness>Other</primaryBusiness>
                <otherBusinessDescription>other</otherBusinessDescription>
                <energyStarPartner>false</energyStarPartner>
            </organization>
          </account>"""

    // make REST Call
    c := EnergyStarClient.makeNoAuth()
    resXml := c.call("POST", `account`, reqXml)
    return resToId(resXml)
  }

//////////////////////////////////////////////////////////////////////////
// App Funcs
//////////////////////////////////////////////////////////////////////////

  @NoDoc @Api @Axon
  static Grid energyStarAppPropertiesList()
  {
    doEnergyStarApp |cx, conn|
    {
      // get all sites keyed by folio id and property id
      sites := cx.proj.readAll("site").sortDis
      sitesById := Ref:Dict[:]
      sitesByPropId := Str:Dict[:]
      sites.each |site|
      {
        sitesById[site.id] = site
        propId := site["energyStarSite"] as Str
        if (propId != null) sitesByPropId[propId] = site
      }

      // read properties for this account
      props := energyStarPropertyList(conn).sortDis
      propsNotLocal := Dict[,]

      // first display mapped properties
      cols := ["id", "dis", "status", "local", "remote"]
      rows := Obj?[,]
      props.each |prop|
      {
        Str propId := prop["id"]
        site := sitesByPropId[propId]
        if (site == null) { propsNotLocal.add(prop); return }
        sitesById.remove(site.id)
        sitesByPropId.remove(propId)
        rows.add([site.id, prop.dis, "Mapped", site.id.toCode, propId])
      }

      // any sites left over not mapped to properies
      sites.each |site|
      {
        if (sitesById[site.id] == null) return
        rows.add([site.id, site.dis, "Missing Remote", site.id.toCode, null])
      }

      // lastly do any properties remote, but not local
      propsNotLocal.each |prop|
      {
        Str propId := prop["id"]
        rows.add([null, prop.dis, "Missing Local", null, propId])
      }

      return Etc.makeListsGrid(conn, cols, null, rows)
    }
  }

  @NoDoc @Api @Axon
  static Grid energyStarAppPropertiesDetails(Obj? siteArg)
  {
    site   := Etc.toRec(siteArg)
    propId := site["energyStarSite"]
    return doEnergyStarApp |cx, conn|
    {
      prop := propId != null ? energyStarPropertyRead(conn, propId) : null

      cols := ["name", "status", "local", "remote"]
      rows := Obj?[,]
      addDetailsRow(rows, "dis", site, prop)
      addDetailsRow(rows, "primaryFunction", site, prop)
      addDetailsRow(rows, "geoStreet", site, prop)
      addDetailsRow(rows, "geoCity", site, prop)
      addDetailsRow(rows, "geoPostalCode", site, prop)
      addDetailsRow(rows, "geoState", site, prop)
      addDetailsRow(rows, "geoCountry", site, prop)
      addDetailsRow(rows, "yearBuilt", site, prop)
      addDetailsRow(rows, "constructionStatus", site, prop)
      addDetailsRow(rows, "area", site, prop)
      addDetailsRow(rows, "occupancyPercentage", site, prop)
      addDetailsRow(rows, "isFederalProperty", site, prop)
      meta := ["view":"table"]
      return Etc.makeListsGrid(meta, cols, null, rows)
    }
  }

  @NoDoc @Api @Axon { admin = true }
  static Obj? energyStarAppPropertyPush(Obj? siteArg)
  {
    siteRef := Etc.toId(siteArg)
    return doEnergyStarApp |cx, conn|
    {
      val := energyStarPropertyPush(conn, siteRef)
      return Etc.makeEmptyGrid(["flashMsg": val])
    }
  }

  @NoDoc @Api @Axon { admin = true }
  static Obj? energyStarAppPropertyPull(Obj? siteArg)
  {
    site   := Etc.toRec(siteArg)
    propId := site["energyStarSite"] ?: throw Err("Site is not mapped yet. Do a 'Push' first")
    return doEnergyStarApp |cx, conn|
    {
      val := energyStarPropertyPull(conn, site["energyStarSite"])
      return Etc.makeEmptyGrid(["flashMsg": val])
    }
  }

  @NoDoc @Api @Axon { admin = true }
  static Obj? energyStarAppPropertyDelete(Obj? siteArg)
  {
    site   := Etc.toRec(siteArg)
    propId := site["energyStarSite"]
    if (propId == null) return Etc.makeEmptyGrid

    return doEnergyStarApp |cx, conn|
    {
      val := energyStarPropertyDelete(conn, propId)
      return Etc.makeEmptyGrid
    }
  }

  @NoDoc @Api @Axon
  static Grid energyStarAppMetersSites()
  {
    doEnergyStarApp |cx, conn|
    {
      cx.proj.readAll("site and energyStarSite").addMeta(conn)
    }
  }

  @NoDoc @Api @Axon
  static Grid energyStarAppMetersInSite(Ref siteId)
  {
    doEnergyStarApp |cx, conn|
    {
      // read the site ands its energy star property id
      site := cx.proj.readById(siteId)
      propId := site["energyStarSite"] as Str
      if (propId == null) throw Err("Site missing energyStarSite tag")

      // get all the main meters for site
      meterEquips := cx.proj.readAll("equip and siteMeter and siteRef==$siteId.toCode")

      // now get all the points for those meters
      points := Dict[,]
      meterEquips.each |meter|
      {
        cx.proj.readAll("point and equipRef==$meter.id.toCode").each |pt| { points.add(pt) }
      }

      // now map points by id and their energy star meterId
      pointsById := Ref:Dict[:]
      pointsByMeterId := Str:Dict[:]
      points.each |pt|
      {
        pointsById[pt.id] = pt
        meterId := pt["energyStarMeter"] as Str
        if (meterId != null) pointsByMeterId[meterId] = pt
      }

      // read meters for this site
      meters := energyStarMeterList(conn, propId).sortDis
      metersNotLocal := Dict[,]

      // first display mapped properties
      cols := ["id", "dis", "status", "local", "remote", "association"]
      rows := Obj?[,]
      meters.each |meter|
      {
        Str meterId := meter["id"]
        assoc := meter["association"]
        pt := pointsByMeterId[meterId]
        if (pt == null) { metersNotLocal.add(meter); return }
        pointsById.remove(pt.id)
        pointsByMeterId.remove(meterId)
        status := assoc != null ? "Mapped" : "Missing Assoc"
        rows.add([pt.id, meter.dis, status, pt.id.toCode, meterId, assoc])
      }

      // any points left over not mapped to meters
      points.each |pt|
      {
        if (pointsById[pt.id] == null) return
        rows.add([pt.id, pt.dis, "Missing Remote", pt.id.toCode, null, null])
      }

      // lastly do any meters remote, but not local
      metersNotLocal.each |meter|
      {
        Str meterId := meter["id"]
        assoc := meter["association"]
        rows.add([null, meter.dis, "Missing Local", null, meterId, assoc])
      }

      return Etc.makeListsGrid(conn, cols, null, rows)
    }
  }

  @NoDoc @Api @Axon
  static Grid energyStarAppMeterDetails(Obj? pointArg)
  {
    point   := Etc.toRec(pointArg)
    meterId := point["energyStarMeter"]
    return doEnergyStarApp |cx, conn|
    {
      meter := meterId != null ? energyStarMeterRead(conn, meterId) : null

      cols := ["name", "status", "local", "remote"]
      rows := Obj?[,]
      addDetailsRow(rows, "dis", point, meter)
      addDetailsRow(rows, "energyStarMeterType", point, meter)
      addDetailsRow(rows, "unit", point, meter)
      addDetailsRow(rows, "firstBillDate", point, meter)
      meta := ["view":"table"]
      return Etc.makeListsGrid(meta, cols, null, rows)
    }
  }

  @NoDoc @Api @Axon { admin = true }
  static Obj? energyStarAppMeterPush(Obj? meterArg)
  {
    meterRef := Etc.toId(meterArg)
    return doEnergyStarApp |cx, conn|
    {
      val := energyStarMeterPush(conn, meterRef)
      return Etc.makeEmptyGrid(["flashMsg": val])
    }
  }

  @NoDoc @Api @Axon { admin = true }
  static Obj? energyStarAppMeterAssoc(Obj? meterArg)
  {
    meter := Etc.toRec(meterArg)
    return doEnergyStarApp |cx, conn|
    {
      resXml := energyStarPropertyAssociationsPush(conn, meter->siteRef)
      return Etc.makeEmptyGrid
    }
  }

  @NoDoc @Api @Axon { admin = true }
  static Obj? energyStarAppMeterPull(Obj? meterArg)
  {
    meter   := Etc.toRec(meterArg)
    meterId := meter["energyStarMeter"] ?: throw Err("Meter not associated yet. Do a 'Push' first")
    return doEnergyStarApp |cx, conn|
    {
      val := energyStarMeterPull(conn, meter->siteRef, meterId)
      return Etc.makeEmptyGrid(["flashMsg": val])
    }
  }

  @NoDoc @Api @Axon { admin = true }
  static Obj? energyStarAppMeterDelete(Obj? meterArg)
  {
    meter   := Etc.toRec(meterArg)
    meterId := meter["energyStarMeter"]
    if (meterId == null) return Etc.makeEmptyGrid

    return doEnergyStarApp |cx, conn|
    {
      val := energyStarMeterDelete(conn, meterId)
      return Etc.makeEmptyGrid(["flashMsg": val])
    }
  }

  private static Grid doEnergyStarApp(|Context cx, Dict conn->Grid| f)
  {
    cx := Context.cur
    conns := cx.proj.readAll("energyStarConn")
    if (conns.size == 0) return Etc.makeEmptyGrid(["connErr":"none"])
    if (conns.size > 1)  return Etc.makeEmptyGrid(["connErr":"tooMany"])
    return f(cx, conns.first)
  }

  private static Void addDetailsRow(Obj?[] rows, Str name, Dict? local, Dict? remote)
  {
    status    := "unknown"
    localVal  := name == "dis" ? local?.dis : local?.get(name)
    remoteVal := remote?.get(name)
    if (local == null || remote == null) status = "warn"
    else if (localVal == remoteVal) status = "ok"
    else if (localVal != null || localVal != null) status = "err"
    rows.add([name, status, localVal, remoteVal])
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static EnergyStarClient toClient(Context cx, Obj? conn)
  {
    if (conn == null) conn = cx.proj.read("energyStarConn")
    rec := conn as Dict ?: cx.proj.readById(conn)
    return EnergyStarClient(cx.proj, rec)
  }

  static Str pointToPropertyId(Proj proj, Dict pt)
  {
    site := proj.readById(pt->siteRef)
    propertyId := site["energyStarSite"] as Str
    if (propertyId == null)throw Err("point site missing energyStarSite: $pt.dis ($pt.id.toCode)")
    return propertyId
  }

  static Str pointToMeterId(Proj proj, Dict pt)
  {
    pointToPropertyId(proj, pt)
    return pt->energyStarMeter
  }

  private static Str resToId(XElem resXml)
  {
    resXml.elem("id").text.val
  }
}

