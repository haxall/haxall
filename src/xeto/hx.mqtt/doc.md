<!--
title:      MqttExt
author:     Matthew Giannini
created:    17 Jan 2022
copyright:  Copyright (c) 2022, SkyFoundry LLC
license:    Licensed under the AFL v3.0
-->

# Overview
The MQTT library implements basic connector support to an MQTT broker. You can publish
messages to a broker, and subscribe to messages from a broker by using the
[hx.obs::Observable.obsMqtt] observable.

# Broker Connectivity
The MQTT library supports connections to a broker using either the `3.1.1` or `5.0`
version of the protocol. The protocol version to use can be configured on the
connector rec using the [MqttConn.mqttVersion] tag.

You can specify the client identifier for the connector to use when connecting to the
broker by setting the [MqttConn.mqttClientId] tag on the connector rec. If one is not specified,
the connector will auto-generate one the first time it connects and save it on the rec.

## TCP/IP
To connect to an MQTT broker over TCP/IP, use the `mqtt` scheme for a plaintext
connection, or `mqtts` for a TLS connection to the broker. If you don't specify a port,
then `1883` will be used for `mqtt` and `8883` will be used for `mqtts`.

```
dis: "MQTT Connector"
conn
mqttConn
uri: `mqtt://192.168.10.1/`
mqttVersion: "v3.1.1"
mqttClientId: "MqttTestClient"
```

## Optional Connect Configuration
By default, the connection to the broker is opened with `cleanSession=false` (3.1.1) and
`cleanStart=false` (5.0). You can set the `mqttCleanSession: true` tag on the connector
rec to force the connection to use cleanSession/cleanStart.

By default, the *session expiry interval* is configured for "on-close", meaning the
broker will retain client session information until the network connection is closed.
Use the `mqttSessionExpiryInterval` tag on the connector rec to specify the duration
for the session to linger after the connection is closed. A value of `-1sec` indicates
that the session should never expire.

## Web Sockets
To connect to an MQTT broker using web sockets, use the `ws` scheme for plaintext
connections, and `wss` for secure web sockets.

```
dis: "MQTT Connector"
conn
mqttConn
uri: `ws://192.168.10.2/`
mqttVersion: "v5"
mqttClientId: "MqttWebSocketTest"
```

## Authentication
By default, the connector will attempt to connect to the MQTT broker anonymously.

If the broker requires a username and password, set the [hx::User.username] tag on the conn
rec and then call [passwordSet()] with the conn rec's id to set the password:

    passwordsSet(@mqttConnId, "password")

Some MQTT brokers require client certificate authentication over TLS. To configure client
certificate authentication, set the [MqttConn.mqttCertAlias] tag to the alias in the crypto manager
that contains your client's private key and certificate.
You can add your private key and certificates to the crypto store for SkySpark using the
[crypto tool](hx.doc.haxall::Crypto) or through the UI as described in the [https section](hx.doc.haxall::Crypto#https)
of the crypto docs.

Some brokers also allow you to connect to the broker over the HTTPS port using
Application-Layer Protocol Negotiation (ALPN). If your broker requires this
type of connectivity, you must set the application protocol on the conn rec using the
`mqttAppProtocols` tag. For example. to connect to an AWS IoT broker on the HTTPS port
using ALPN you might set up a connector like this

```
mqttConn
uri: `mqtts://foo-ats.iot.eu-west-1.amazonaws.com:443`
mqttVersion: "v3.1.1"
mqttCertAlias: "myMqttClient"
mqttClientId: "MyAwsThing"
mqttAppProtocols: "x-amzn-mqtt-ca"
```

# Publish
To publish a message to the broker use the [mqttPublish()] func.

```
read(@myMqttConn).mqttPublish("testTopic", "Hello, MQTT!", {mqttQos: 2})
```

# Subscribe
MQTT topic subscription is handled using the task framework. Create a task
that subscribes to the [hx.obs::Observable.obsMqtt] observable. The [hx.obs::Observable.obsMqtt] observable fires an event
whenever a message is received that matches configured topic filter.

MQTT observations include the following tags:
- `type`: "obsMqtt"
- `ts`: DateTime when the observation was fired
- `topic`: the name of the topic that the message was published to.
- `payload`: the payload of the published message. This will be a Fantom [fan.sys::Buf]
object. But you can use the various 'io'  functions to read/parse the payload.
- `userProps`: the user properties of the published message. This will be a `Dict`
where the keys and values are both 'Str'. User properties are a feature of MQTT v5 only.

These are the config tags:

- [hx.obs::Observable.mqttQos]: The maximum quality-of-service guarantee you are willing to accept
for published messages.
- [hx.obs::Observable.obsMqttConnRef]: Which connector to subscribe to the topic on
- [hx.obs::Observable.obsMqttTopic]: the topic filter to subscribe with. This may be a specific topic,
or a valid MQTT topic filter. If it is a filter, then your task will receive
messages for potentially multiple topics.

```
obsMqtt
obsMqttConnRef: @myMqttConn
obsMqttTopic: "test/#"
mqttQos: 2
taskExpr:
(obs) => do
  logInfo("mqttTask", ioReadStr(obs->payload))
end
```

# MQTT Points
Due to the open nature of MQTT payloads, the MQTT basic connector does not include
direct support for points like there are for other connectors. In order to use
values from an MQTT topic subscription, [hx.obs::Observable.obsMqtt] tasks can use different approaches
based on the message format and requirements:

1. Make transient commits to the [ph::PhEntity.curVal] and [ph::PhEntity.curStatus] tags of a point record and
allow the `hisCollectCov` or `hisCollectInterval` configuration to trend the data
1. Use [hisWrite()] to directly write historical data to a point record

Since there is no standard format for an MQTT message payload the [hx.obs::Observable.obsMqtt] task
must get the value(s) out of the message and determine what point record to
commit/write the values to.

There could be several ways to determe the point record to write to. One way could
simply be using the topic the message is published to and storing the topic
on the point record.

For example, imagine each published message has this format:

```
{
  "theValue": "79.6",
  "sensor": "temperature",
  "unit": "°F"
}
```

Then one way to configure the task is shown below:

```
obsMqtt
obsMqttConnRef: @myMqttConn
obsMqttTopic: "#"
mqttQos: 2
taskExpr:
(obs) => do
  msg: ioReadJson(obs->payload, {safeNames})
  myPoint: read(myMqttTopic == obs->topic, false)
  if (myPoint != null)
    diff(myPoint, {curVal:parseNumber(msg->theValue).as(msg->unit), curStatus:"ok"}, {transient}).commit
end
```

