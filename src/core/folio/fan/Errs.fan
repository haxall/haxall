//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Feb 2009  Brian Frank  Creation
//

using haystack

** Invalid record id
@NoDoc
const class InvalidRecIdErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid tag name string
@NoDoc
const class InvalidTagNameErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Invalid tag value
@NoDoc
const class InvalidTagValErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Indicates access after database is closed
@NoDoc
const class ShutdownErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Indicates attempt to write to a readonly replica
@NoDoc
const class ReadonlyReplicaErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Improperly constructured diff
@NoDoc
const class DiffErr : Err
{
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

** Commit failure
@NoDoc
const class CommitErr : Err
{
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

** Commit failure due to concurrent changes.  It is thrown when
** the current version of a commit doesn't match the read version.
@NoDoc
const class ConcurrentChangeErr : CommitErr
{
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

** Load failure
@NoDoc
const class LoadErr : CommitErr
{
  new make(Str? msg, Err? cause := null) : super(msg, cause) {}
}

** Error on a specific record
@NoDoc
const class RecErr : Err
{
  new make(Dict rec, Str msg, Err? cause := null) : super(toRecMsg(rec, msg), cause) { this.rec = rec }

  const Dict rec

  private static Str toRecMsg(Dict rec, Str msg)
  {
    id := rec["id"] as Ref
    if (id != null)
    {
      idStr := id.toZinc
      if (msg.isEmpty) return idStr
      return "$msg [$idStr]"
    }
    return msg
  }
}

** His configuration failure
@NoDoc
const class HisConfigErr : RecErr
{
  new make(Dict rec, Str msg, Err? cause := null) : super(rec, msg, cause) {}
}

** His write failure
@NoDoc
const class HisWriteErr : RecErr
{
  new make(Dict rec, Str msg, Err? cause := null) : super(rec, msg, cause) {}
}

