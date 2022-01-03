//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  12 Apr 2021   Matthew Giannini  Creation
//

**
** A message contains the application payload and delivery options for a
** publish packet.
**
const class Message
{
  new make(|This| f) { f(this) }

  new makeFields(Buf payload, QoS qos := QoS.one, Bool retain := false, |This|? f := null)
  {
    f?.call(this)
    this.payload = payload
    this.qos     = qos
    this.retain  = retain
  }

  ** The application payload.
  **
  ** Since it is 'const' make sure you use [payload.in]`sys::Buf.in` to read
  ** the contents of the payload.
  const Buf payload

  ** The requested [quality of service]`QoS`
  const QoS qos

  ** Should the message be retained?
  const Bool retain

  ** Set to true to notify the server and all recipients that the payload
  ** of the message is UTF-8 encoded character data. If false, the payload
  ** is treated as unspecified bytes
  **
  ** This option only applies to clients with version >= 5
  const Bool utf8Payload := false

  ** If specified, this is the lifetime of the application message in seconds.
  ** If the message expirty interval has passed and the server has not managed
  ** to start onward delivery to a matching subscriber, then the server MUST
  ** delete the copy of the message for that subscriber.
  **
  ** If null, the application message does not expire.
  **
  ** This option only applies to clients with version >= 5
  const Duration? expiryInterval := null

  ** The topic alias for this message.
  **
  ** This option only applies to clients with version >= 5
  internal const Int? topicAlias := null

  ** The topic name for a response message
  **
  ** This option only applies to clients with version >= 5
  ** TODO:FIXIT add better support in the API for request/response handling
  internal const Str? responseTopic := null

  ** The correlation data is used by the send of the request message to identify
  ** which request the response message is for when it is received. It only
  ** has meaning to the sender of request message and receiver of the response message.
  **
  ** This option only applies to clients with version >= 5
  ** TODO:FIXIT add better support in the API for request/response handling
  internal const Buf? correlationData := null

  ** User properties to send as part of the message.
  **
  ** This setting only applies to clients with version >= 5
  const StrPair[] userProps := [,]

  ** Subscription identifiers that match this publication.
  **
  ** This setting only applies to clients with version >= 5
  ** TODO:FIXIT add support for subscription ids
  internal const Int[] subscriptionIds := [,]

  ** The content type of the application message
  **
  ** This setting only applies to clients with version >= 5
  const Str? contentType := null

  ** Get the message properties from the configured fields.
  Properties props()
  {
    props := Properties()
      .add(Property.payloadFormatIndicator, utf8Payload ? 1 : 0)
      .add(Property.messageExpiryInterval, expiryInterval?.toSec)
      .add(Property.topicAlias, topicAlias)
      .add(Property.responseTopic, responseTopic)
      .add(Property.correlationData, correlationData)
      .add(Property.contentType, contentType)
    userProps.each |userProp| { props.add(Property.userProperty, userProp) }
    subscriptionIds.each |id| { props.add(Property.subscriptionId, id) }
    return props
  }

}