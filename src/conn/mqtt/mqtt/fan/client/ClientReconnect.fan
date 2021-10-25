//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  25 Oct 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** ClientAutoReconnect
**************************************************************************

**
** Client auto-reconnect strategies implement this mixin.
**
mixin ClientAutoReconnect : ClientListener
{
}

**************************************************************************
** Default
**************************************************************************

**
** Default auto-reconnect uses an exponential back-off strategy to
** implement auto-reconnect logic.
**
internal const class DefaultAutoReconnect : Actor, ClientAutoReconnect
{
  new make(MqttClient client, |This|? f := null)
    : super.makeCoalescing(client.config.pool, null, null)
  {
    f?.call(this)
    this.client = client
  }

  private const MqttClient client
  private Log log() { client.log }
  const Duration initialDelay
  const Duration maxDelay

  private const AtomicInt curDelay := AtomicInt(-1)
  private const AtomicInt numRetries := AtomicInt(0)
  private const AtomicInt disconnectTs := AtomicInt(0)

  private static const ActorMsg reconnectMsg := ActorMsg("reconnect")

  override Void onDisconnected()
  {
    send(ActorMsg("disconnect"))
  }

  protected override Obj? receive(Obj? obj)
  {
    msg := (ActorMsg)obj
    switch (msg.id)
    {
      case "disconnect": return onInitialDisconnect
      case "reconnect": return onReconnect
      default: throw Err("Unexpected msg: $msg")
    }
  }

  private Obj? onInitialDisconnect()
  {
    // reset curDelay back to initial ticks and schedule first reconnect attempt
    disconnectTs.val = DateTime.nowTicks
    curDelay.val = initialDelay.ticks
    log.info("Client disconnected. Attempting to reconnect...")
    return sendLater(initialDelay, reconnectMsg)
  }

  private Obj? onReconnect()
  {
    try
    {
      client.connect.get
      elapsed := Duration.make(DateTime.nowTicks - disconnectTs.val)
      log.info("Reconnected after ${elapsed.toLocale}!")
      numRetries.val = 0
    }
    catch (Err err)
    {
      scheduleNextAttempt(err)
    }
    return null
  }

  private Void scheduleNextAttempt(Err? err := null)
  {
    numRetries.increment
    curDelay.val = (2 * curDelay.val).min(maxDelay.ticks)
    dur := Duration(curDelay.val)
    debug("Reconnect [${numRetries.val}] failed. Next attempt in ${dur.toLocale}", err)
    sendLater(dur, reconnectMsg)
  }

  private Void debug(Str msg, Err? err := null)
  {
    if (log.isDebug)
      log.debug(msg, err)
  }
}