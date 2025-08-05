//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2021  Brian Frank  Creation
//  13 Jul 2025  Brian Frank  Refactor for 4.0
//

using obs

**
** Runtime observable APIs
**
const mixin RuntimeObservables
{
  ** List the published observables for the project
  abstract Observable[] list()

  ** Lookup a observable for the project by name.
  abstract Observable? get(Str name, Bool checked := true)

  ** Get the schedule observable
  @NoDoc abstract ScheduleObservable schedule()
}

