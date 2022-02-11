//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Feb 2022  Matthew Giannini  Creation
//

using oauth2

**
** Ecobee Report Request API
**
class ReportReq : ApiReq
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  internal new make(Ecobee ecobee) : super(ecobee.client, ecobee.log)
  {
  }

//////////////////////////////////////////////////////////////////////////
// API
//////////////////////////////////////////////////////////////////////////

  RuntimeReportResp runtime(RuntimeReportReq req)
  {
    query := ["format":"json", "body": EcobeeEncoder.jsonStr(req)]
    json  := invoke("GET", baseUri.plus(`runtimeReport`).plusQuery(query))
    return EcobeeDecoder().decode(json, RuntimeReportResp#)
  }
}

**************************************************************************
** RuntimeReportReq
**************************************************************************

const class RuntimeReportReq : EcobeeObj
{
  new make(|This| f) { f(this) }

  const EcobeeSelection selection

  ** The UTC report start date
  const Date startDate

  ** The report start interval
  const Int? startInterval

  ** The UTC report end date
  const Date endDate

  ** The report end interval
  const Int? endInterval

  ** A CSV string of column names. No spaces in CSV.
  const Str columns

  const Bool? includeSensors
}

**************************************************************************
** RuntimeReportResp
**************************************************************************

final const class RuntimeReportResp : EcobeeResp
{
  new make(|This| f) : super(f) { f(this) }

  ** The report UTC start date
  const Date startDate

  ** The report start interval
  const Int startInterval

  ** The report UTC end date
  const Date endDate

  ** The report end interval
  const Int endInterval

  ** The CSV list of column names from the request.
  const Str columns

  ** A list of runtime reports
  const EcobeeRuntimeReport[] reportList

}