//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  09 Apr 2021   Matthew Giannini  Creation
//

using concurrent

**
** Configuration for a CONNECT request
**
const class ConnectConfig
{
  new make(|This|? f := null) { f?.call(this) }

  ** The MQTT protocol revision to use
  internal MqttVersion version() { versionRef.val }
  internal const AtomicRef versionRef := AtomicRef(MqttVersion.v3_1_1)

  ** The keep-alive time interval (which will be converted to seconds)
  const Duration keepAlive := 60sec

  ** Is a clean session (v3) or clean start (v5) requested
  const Bool cleanSession := true

  ** The username
  const Str? username := null

  ** The password
  const Buf? password := null

  ** How long to wait for CONNACK after the CONNECT message is sent
  const Duration connectTimeout := 10sec

  ** The session expiry interval (in seconds).
  ** If set to '0', the session ends when the network connection is closed.
  ** If set to '0xFFFF_FFFF' the session does not expire.
  **
  ** This setting only applies to clients with version >= 5
  const Duration sessionExpiryInterval := MqttConst.sessionExpiresOnClose

  ** Used to limit the number of QoS 1 and QoS 2 publications that the client
  ** is willing to process concurrently. May not set to zero.
  **
  ** This setting only applies to clients with version >= 5
  const Int? receiveMax := null

  ** The maximum packets size the client is willing to accept.
  ** May not be set to zero. If set to null, there is no limit on the packet size.
  **
  ** This setting only applies to clients with version >= 5
  const Int? maxPacketSize := null

  ** The maximum value the client will accept a a topic alias sent by the server.
  **
  ** This setting only applies to clients with version >= 5
  ** TODO:FIXIT add support for topic aliases
  private const Int topicAliasMax := 0

  ** If true, the client is requesting the server to return response information
  ** in the CONNACK (but the server may choose not to).
  **
  ** This setting only applies to clients with version >= 5
  const Bool requestResponseInfo := false

  ** If 'false', the server may return a reason string or user properties on
  ** a CONNACK or DISCONNECT packet, but MUST NOT send a reason string or
  ** user properties on any packet other than PUBLISH, CONNACK, or DISCONNECT.
  **
  ** If 'true', the server may return a reason string or user properties on any
  ** packet where it is allowed.
  **
  ** This setting only applies to clients with version >= 5
  const Bool requestProblemInfo := true

  ** User properties to send as part of the connection request.
  **
  ** This setting only applies to clients with version >= 5
  const StrPair[] userProps := [,]

  ** The authentication method to use. If null, extended authentication
  ** is not performed.
  **
  ** This setting only applies to clients with version >= 5
  const Str? authMethod := null

  ** The authentication data.
  **
  ** This setting only applies to clients with version >= 5
  const Buf? authData := null

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Build a connect packet for this configuration with the given client identifier
  internal Connect packet(Str clientId)
  {
    Connect
    {
      it.version      = this.version
      it.clientId     = clientId
      it.keepAlive    = this.keepAlive
      it.cleanSession = this.cleanSession
      it.username     = this.username
      it.password     = this.password
      it.props        = this.toProps
    }
  }

  private Properties toProps()
  {
    props := Properties()
      .add(Property.sessionExpiryInterval, sessionExpiryInterval.toSec)
      .add(Property.receiveMax, receiveMax)
      .add(Property.maxPacketSize, maxPacketSize)
      .add(Property.topicAliasMax, topicAliasMax)
      .add(Property.requestResponseInfo, requestResponseInfo ? 1 : 0)
      .add(Property.authMethod, authMethod)
      .add(Property.authData, authData)
    userProps.each |userProp| { props.add(Property.userProperty, userProp) }
    return props
  }
}