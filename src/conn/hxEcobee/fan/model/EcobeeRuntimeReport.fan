//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Feb 2022  Matthew Giannini  Creation
//

**
** RuntimeReport object
**
const class EcobeeRuntimeReport : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  ** The thermostat identifier for the report
  const Str? thermostatIdentifier

  override Str? id() { thermostatIdentifier }

  ** The number of report rows in this report
  const Int? rowCount

  ** A list of CSV report string based on the columns requested
  ** A runtime report row is composed of a CSV string containing
  ** the Date, Time, and the user selected columns.
  const Str[] rowList
}