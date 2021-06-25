//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2021  Brian Frank  Creation
//

using haystack

**
** CommitObservation is an observation event for an 'obsCommit' stream.
**
@NoDoc
const class CommitObservation
{
  // TODO
  static Observation make(Observable observable, CommitObservationType type, DateTime ts, Ref id, Dict oldRec, Dict newRec, Dict? user)
  {
    body := user == null ?
            Etc.makeDict4("subType", type.name, "id", id, "oldRec", oldRec, "newRec", newRec) :
            Etc.makeDict5("subType", type.name, "id", id, "oldRec", oldRec, "newRec", newRec, "user", user)
    return MObservation(observable, ts, body)
  }

  private new makeImpl() {}
}

**************************************************************************
** CommitObservationType
**************************************************************************

enum class CommitObservationType
{
  added,
  updated,
  removed
}


