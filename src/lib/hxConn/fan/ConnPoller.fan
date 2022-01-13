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

    if (lib.isRunning) sendLater(checkFreq, checkMsg)
    return null
  }

  ** Check all the connectors for poll callback
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
        conn.pollNext.val = now + pollInitStaggerConn(conn)
        return
      }

      // update nextPoll and enqueue execute message
      now = Duration.nowTicks
      conn.pollNext.val = now + freq
      conn.send(Conn.pollMsg)
    }
  }

  ** Connector level stagger is for sending the Conn its first poll message.
  ** For manual polling this is the initial onPollManual callback.  For buckets,
  ** its just the first time we scan the buckets.
  static Int pollInitStaggerConn(Conn conn)
  {
    pollInitStagger(conn.pingFreq ?: 10sec)
  }

  ** Bucket level stagger is within buckets of a given tuning config.
  ** For example if we have multiple buckets of 10sec, then the stagger
  ** those buckets so they aren't all polled simultaneously
  static Int pollInitStaggerBucket(ConnTuning tuning)
  {
    pollInitStagger(tuning.pollTime)
  }

  ** Compute the initial poll stagger freq.  We attempt to stagger
  ** initial polls to prevent every connector polling at the same time
  ** which can spike the CPU and flood the network.  This method
  private static Int pollInitStagger(Duration pollTime)
  {
    return pollTime.ticks * (0..100).random / 100
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

  Int nextPoll() { state.nextPoll.val }

  internal Void updateNextPoll(Int startTicks)
  {
    lastPoll := Duration.nowTicks
    lastDur := lastPoll - startTicks

    state.lastPoll.val = lastPoll
    state.lastDur.val  = lastDur
    state.nextPoll.val = lastPoll + pollTime.ticks
    state.numPolls.increment
    state.totalDur.add(lastDur)
  }

  override Int compare(Obj that)
  {
    tuning.pollTime <=> ((ConnPollBucket)that).tuning.pollTime
  }

  override Str toStr()
  {
    "$tuning.dis [$tuning.pollTime, $points.size points] $state"
  }
}

** ConnPollBucketState only updated by Conn actor thread
@NoDoc
const class ConnPollBucketState
{
  new make(ConnTuning tuning)
  {
    nextPoll.val = Duration.nowTicks + ConnPoller.pollInitStaggerBucket(tuning)
  }

  const AtomicInt nextPoll := AtomicInt()
  const AtomicInt lastPoll := AtomicInt()
  const AtomicInt numPolls := AtomicInt()
  const AtomicInt lastDur  := AtomicInt()
  const AtomicInt totalDur := AtomicInt()

  override Str toStr()
  {
    "nextPoll: " + Etc.debugDur(nextPoll.val) +
    ", lastPoll: " + Etc.debugDur(lastPoll.val) +
    ", lastDur: " + Duration(lastDur.val).toLocale +
    ", # polls: " + numPolls.val +
    ", avgPoll: " + (numPolls.val == 0 ? "n/a" : Duration(totalDur.val/numPolls.val).toLocale)
  }
}

