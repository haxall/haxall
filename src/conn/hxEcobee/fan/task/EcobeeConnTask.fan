//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   02 Feb 2022  Matthew Giannini  Creation
//

using xeto
using haystack
using hxConn

**
** Base class for Ecobee connetor tasks
**
internal abstract class EcobeeConnTask
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(EcobeeDispatch dispatch)
  {
    this.dispatch = dispatch
  }

  EcobeeDispatch dispatch { private set }
  Ecobee client() { dispatch.client }
  Conn conn() { dispatch.conn }
  Log log() { dispatch.trace.asLog }

//////////////////////////////////////////////////////////////////////////
// ConnTask
//////////////////////////////////////////////////////////////////////////

  abstract Obj? run()

//////////////////////////////////////////////////////////////////////////
// PointUtils
//////////////////////////////////////////////////////////////////////////

  internal static EcobeePropId toCurId(ConnPoint pt) { toRemoteId(pt.rec, "ecobeeCur") }

  internal static EcobeePropId toWriteId(ConnPoint pt) { toRemoteId(pt.rec, "ecobeeWrite") }

  internal static EcobeePropId toHisId(ConnPoint pt) { toRemoteId(pt.rec, "ecobeeHis") }

  internal static EcobeePropId toRemoteId(Dict rec, Str tag)
  {
    val := rec[tag]
    if (val == null)   throw FaultErr("$tag not defined")
    if (val isnot Str) throw FaultErr("$tag must be a Str: $val.typeof.name")
    return EcobeePropId.fromStr(val)
  }

  Dict pointData(ConnPoint pt) { pt.data as Dict ?: Etc.dict0 }
}

**************************************************************************
** EcobeePropId
**************************************************************************

@NoDoc const class EcobeePropId
{
  static new fromStr(Str s) { EcobeePropId(s.toUri) }

  private new make(Uri uri)
  {
    this.uri = uri
    if (uri.path.size < 2) throw ArgErr("Invalid property id: $uri")
    this.thermostatId = uri.path[0]
    this.propSpecs = uri.path[1..-1].map { EcobeePropSpec.fromStr(it) }
    if (propSpecs.last.isObjectSelect) throw ArgErr("Property id must not end with a selector: $uri")
  }

  ** Full URI of the property
  const Uri uri

  ** The thermostat id
  const Str thermostatId

  ** Path of property specs
  const EcobeePropSpec[] propSpecs

  ** Get the thermostat relative uri of the property
  Uri propUri() { propSpecs.join("/").toUri }

  ** Is this a Settings object property
  Bool isSettings() { propSpecs.first.prop == "settings" }

  ** Is this a Runtime object property
  Bool isRuntime() { propSpecs.first.prop == "runtime" }

  override Str toStr() { uri.toStr }
}

**************************************************************************
** EcobeePropSpec
**************************************************************************

@NoDoc const class EcobeePropSpec
{
  ** <prop-name>('[' (<keyProp> = )<val> ']')
  **
  **   capability[type=temperature]
  **   runtimeSensors[rs:100]
  static new fromStr(Str s)
  {
    selectIdx := s.index("[")
    if (selectIdx == null) return EcobeePropSpec(s, null, null)

    prop   := s[0..<selectIdx]
    select := s[(selectIdx+1)..<-1].split('=')
    key := select.size == 1 ? "id" : select.first
    val := select.last
    return EcobeePropSpec(prop, key, val)
  }

  new make(Str prop, Str? selectKey, Str? selectVal)
  {
    this.prop = prop
    this.selectKey = selectKey
    this.selectVal = selectVal
  }

  ** The property name
  const Str prop

  const Str? selectKey

  const Str? selectVal

  ** Is this a property spec for an object selector?
  Bool isObjectSelect() { selectKey != null }

  ** Is this an object selector based on its id?
  Bool isIdSelector() { selectKey == "id" }

  override Str toStr() { selectKey == null ? prop : "${prop}[$selectKey=$selectVal]" }
}

