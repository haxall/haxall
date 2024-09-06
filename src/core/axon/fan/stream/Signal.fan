//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2019  Brian Frank  Creation
//

using concurrent

**
** Signal is used to pass out-of-band events across streams
**
@NoDoc @Js
const class Signal
{
  // constants
  static const Signal start    := Signal(SignalType.start)
  static const Signal complete := Signal(SignalType.complete)

    ** Constructor
  new make(SignalType type, Obj? a := null, Obj? b := null)
  {
    this.type = type
    this.a    = a
    this.b    = b
  }

  ** Signal type enum
  const SignalType type

  ** First optional argument
  const Obj? a

  ** Second optional argument
  const Obj? b

  ** Does this signal stream completion
  Bool isComplete() { type.isComplete }

  ** Debug string
  override Str toStr() { ActorMsg.toDebugStr("Signal", type, a, b) }
}

**************************************************************************
** SignalType
**************************************************************************

@NoDoc @Js
enum class SignalType
{
  start,
  err(true),
  complete(true),
  setMeta,
  addMeta,
  setColMeta,
  addColMeta,
  reorderCols,
  keepCols,
  removeCols

  private new make(Bool isComplete := false) { this.isComplete = isComplete }

  const Bool isComplete
}

