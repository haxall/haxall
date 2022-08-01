//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using haystack
using hxConn

**
** Utility to synchronize the curVal for a list of points
**
internal class EcobeeSyncCur : EcobeeConnTask
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(EcobeeDispatch dispatch, ConnPoint[] points) : super(dispatch)
  {
    this.points = points
  }

  private const ConnPoint[] points

  ** The latest thermostat summary
  private ThermostatSummaryResp? summary

  ** These are the points we will actually sync updates for
  private ConnPoint[] stalePoints := ConnPoint[,]

  ** Stale thermostat identifiers
  private [Str:Bool] staleThermostats := [:]

//////////////////////////////////////////////////////////////////////////
// Sync
//////////////////////////////////////////////////////////////////////////

  override Obj? run()
  {
    init
    sync
    return null
  }

  private Void init()
  {
    this.summary = dispatch.pollSummary
    revisions := summary.revisions

    // find stale points
    points.each |point|
    {
      // resolve the point to a thermostat known by the ecobee server
      propId := toCurId(point, false)
      if (propId == null) return

      rev := revisions[propId.thermostatId]
      if (rev == null)
      {
        return point.updateCurErr(FaultErr("Thermostat not registered at Ecobee server: ${propId.thermostatId}"))
      }

      // check if the point data is stale
      data     := pointData(point)
      lastSync := data["runtimeRev"] as Str
      if (rev.runtimeRev != lastSync)
      {
        stalePoints.add(point)
        staleThermostats[propId.thermostatId] = true
      }
    }
  }

  private Void sync()
  {
    // short-circuit if nothing is stale
    if (stalePoints.isEmpty) return

    selection := EcobeeSelection {
      it.selectionType   = SelectionType.thermostats
      it.selectionMatch  = staleThermostats.keys.join(",")
      it.includeRuntime  = true
      it.includeSensors  = true
      it.includeSettings = true
      it.includeEquipmentStatus = true
    }
    thermostats := [Str:EcobeeThermostat][:]
      .setList(client.thermostat.get(selection)) { it.identifier }

    stalePoints.each |point|
    {
      try
      {
        propId := toCurId(point)
        thermostat := thermostats[propId.thermostatId]

        if (thermostat == null)
          throw FaultErr("Thermostat not returned by Ecobee server for: $propId")

        val := resolveVal(propId, thermostat)
        val = coerce(val, point, propId)
        point.updateCurOk(val)

        // update point data with latest revision
        data := Etc.dictMerge(pointData(point), ["runtimeRev": thermostat.runtime.runtimeRev])
        dispatch.setPointData(point, data)
      }
      catch (Err err)
      {
        point.updateCurErr(err)
      }
    }
  }

  private Obj? resolveVal(EcobeePropId propId, EcobeeThermostat thermostat)
  {
    // sanity check
    if (propId.thermostatId != thermostat.identifier)
      throw FaultErr("Illegal State $propId != $thermostat.identifier")

    Obj? obj := thermostat
    propId.propSpecs.each |spec|
    {
      try
      {
        // resolve the prop spec on the current object
        field := obj.typeof.field(spec.prop)
        obj = field.get(obj)

        // if its an object selector, we find the matching object in the set
        if (spec.isObjectSelect)
        {
          if (obj isnot List) throw FaultErr("$spec does not resolve to a list")
          list := obj as EcobeeObj[]
          if (list == null) throw FaultErr("$spec does not resolve to an ecobee object list")
          obj = list.find |item|
          {
            if (spec.isIdSelector) return item.id == spec.selectVal
            else
            {
              field = item.typeof.field(spec.selectKey)
              // this assumes the value on the object is a Str
              return field.get(item) == spec.selectVal
            }
          }
          if (obj == null) throw FaultErr("$spec did not match any objects")
        }
        else if (obj is List) throw FaultErr("$spec resolves to a list, but does not have an object selector")
      }
      catch (UnknownSlotErr err)
      {
        throw FaultErr("Could not resolve $spec on ${obj.typeof}" , err)
      }
    }

    return EcobeeUtil.toHay(obj)
  }

  private Obj? coerce(Obj? val, ConnPoint point, EcobeePropId propId)
  {
    if (val == null) return null
    if (point.kind.name == "Bool" && val is Str) return Bool.fromStr(val)
    return val
  }
}