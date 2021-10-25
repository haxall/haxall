//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  25 Oct 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** ClientListener
**************************************************************************

**
** ClientListener is used to register callback handlers for various client events
**
mixin ClientListener
{
  ** Callback when the client has connected to the broker. This
  ** means the broker has responded to a 'CONNECT' message with a
  ** successful 'CONNACK' response.
  virtual Void onConnected() { }

  ** Callback when the client has been disconnected from the broker. This
  ** happen for several reasons:
  ** - client initiated 'DISCONNECT' packet is sent
  ** - server initiated 'DISCONNECT' packet is received
  ** - client 'CONNECT' times out (no 'CONNACK' received)
  ** - network disruption causes existing socket to be closed.
  virtual Void onDisconnected() { }
}

**************************************************************************
** ClientListeners
**************************************************************************

**
** This actor handles registering and firing events on client listeners.
** We want this actor so that callback handling doesn't block the client actor.
**
internal const class ClientListeners : Actor
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MqttClient client) : super(client.config.pool)
  {
    this.client = client
  }

  private const MqttClient client
  private Log log() { client.log }

  private ClientListener[] listeners() { listenersRef.val }
  private const Unsafe listenersRef := Unsafe(ClientListener[,])

//////////////////////////////////////////////////////////////////////////
// ClientListeners
//////////////////////////////////////////////////////////////////////////

  Void addListener(ClientListener listener)
  {
    send(ActorMsg("add", Unsafe(listener))).get
  }

  Future fireConnected()
  {
    send(ActorMsg("connected"))
  }

  Future fireDisconnected()
  {
    send(ActorMsg("disconnected"))
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  protected override Obj? receive(Obj? obj)
  {
    msg := (ActorMsg)obj
    switch (msg.id)
    {
      case "add":          return onAddListener(msg.a->val)
      case "connected":    return onConnected
      case "disconnected": return onDisconnected
      default: throw ArgErr("Unexpected msg: $msg")
    }
  }

  private Obj? onAddListener(ClientListener listener)
  {
    listeners.add(listener)
    return true
  }

  private Obj? onConnected()
  {
    listeners.each |listener|
    {
      try
        listener.onConnected
      catch (Err err)
        log.err("Listener $listener failed onConnected", err)
    }
    return null
  }

  private Obj? onDisconnected()
  {
    listeners.each |listener|
    {
      try
        listener.onDisconnected
      catch (Err err)
        log.err("Listener $listener failed onDisconnected", err)
    }
    return null
  }
}
