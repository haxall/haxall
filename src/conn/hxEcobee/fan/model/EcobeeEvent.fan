//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Feb 2022  Matthew Giannini  Creation
//

**
** Event object
**
const class EcobeeEvent : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  ** The type of event. Values: hold, demandResponse, sensor, switchOccupancy,
  ** vacation, quickSave, today, autoAway, autoHome
  const Str? type

  ** The unique event name
  const Str? name

  ** Whether the event is currently active or not
  const Bool? running

  // TODO: a bunch more properties

  ** The cooling absolute temperature to set
  const Int? coolHoldTemp

  ** The heating absolute temperature to set
  const Int? heatHoldTemp

}