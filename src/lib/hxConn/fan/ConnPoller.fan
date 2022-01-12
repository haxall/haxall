//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jun 2012  Brian Frank  Creation
//   21 Jan 2022  Brian Frank  Redesign for Haxall
//

using concurrent
using haystack

**
** ConnPoller is a single actor used by a connector library for
** checking poll frequency of all connectors and scheduling polls.
**
internal const class ConnPoller : Actor
{
  internal new make(ConnLib lib) : super(lib.rt.libs.actorPool)
  {
    this.lib = lib
  }

  const ConnLib lib

  Void onStart() { send(checkMsg) }

  override Obj? receive(Obj? msg)
  {
    if (msg !== checkMsg) return null

    try
      check
    catch (Err e)
      lib.log.err("ConnPoller.receive", e)

    sendLater(checkFreq, checkMsg)
    return null
  }

  private Void check()
  {
    now := Duration.nowTicks
    lib.conns.each |conn|
    {
      // if not at our deadline skip
      pollNext := conn.pollNext.val
      if (pollNext > now) return

      // if we don't have a poll frequency, skip it
      freq := conn.pollFreqEffective
      if (freq <= 0) return

      // randomize first poll time to stagger across connectors
      if (pollNext == 0)
      {
        conn.pollNext.val = now + conn.pollInitStagger
        return
      }

      // update nextPoll and enqueue execute message
      now = Duration.nowTicks
      conn.pollNext.val = now + freq
      conn.send(Conn.pollMsg)
    }
  }

  private const static Duration checkFreq := 10ms
  private const static Str checkMsg := "check!"
}

**************************************************************************
** ConnPollingMode
**************************************************************************

**
** The polling modes supported by the connector framework
**
enum class ConnPollMode
{
  ** Polling not supported
  disabled,

  ** Cnnector implementation handles all polling logic
  manual,

  ** Connector framework handles the polling logic using buckets strategy
  buckets

  ** Return 'true' if the mode is not `disabled`.
  Bool isEnabled() { this !== disabled }
}

**************************************************************************
** ConnPollBucket
**************************************************************************

**
** Bucket of points for connectors using the bucket strategy
**
@NoDoc
const class ConnPollBucket
{
  new make(Conn conn, ConnTuning tuning, ConnPollBucketState state, ConnPoint[] points)
  {
    this.conn   = conn
    this.tuning = tuning
    this.state  = state
    this.points = points
  }

  const Conn conn
  const ConnTuning tuning
  const ConnPollBucketState state
  const ConnPoint[] points
  Duration pollTime() { tuning.pollTime }
  override Int compare(Obj that)
  {
    tuning.pollTime <=> ((ConnPollBucket)that).tuning.pollTime
  }
}

@NoDoc
const class ConnPollBucketState
{
}

