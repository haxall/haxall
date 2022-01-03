//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  06 Apr 2021   Matthew Giannini  Creation
//

using mqtt::PacketType as PT

**
** MQTT reason codes. These codes are based off the version 5 spec but the code for reasons
** that have a mapping to 3.1.1 codes can be obtained using 'v3()'.
**
enum class ReasonCode
{
  success(0, [PT.connack, PT.puback, PT.pubrec, PT.pubrel, PT.pubcomp, PT.unsuback, PT.auth]),
  normal_disconnection(0, [PT.disconnect]),
  granted_qos0(0, [PT.suback]),
  granted_qos1(1, [PT.suback]),
  granted_qos2(2, [PT.suback]),
  disconnect_with_will_message(4, [PT.disconnect]),
  no_matching_subscribers(16, [PT.puback, PT.pubrec]),
  no_subscription_existed(17, [PT.unsuback]),
  continue_auth(24, [PT.auth]),
  reauthenticate(25, [PT.auth]),
  unspecified_error(128, [PT.connack, PT.puback, PT.pubrec, PT.suback, PT.unsuback, PT.disconnect]),
  malformed_packet(129, [PT.connack, PT.disconnect]),
  protocol_error(130, [PT.connack, PT.disconnect]),
  implementation_specific_error(131, [PT.connack, PT.puback, PT.pubrec, PT.suback, PT.unsuback, PT.disconnect]),
  unsupported_protocol_version(132, [PT.connack]),
  client_identifier_not_valid(133, [PT.connack]),
  bad_username_or_password(134, [PT.connack]),
  not_authorized(135, [PT.connack, PT.puback, PT.pubrec, PT.suback, PT.unsuback, PT.disconnect]),
  server_unavailable(136, [PT.connack]),
  server_busy(137, [PT.connack, PT.disconnect]),
  banned(138, [PT.connack]),
  server_shutting_down(139, [PT.disconnect]),
  bad_auth_method(140, [PT.connack, PT.disconnect]),
  keep_alive_timeout(141, [PT.disconnect]),
  session_taken_over(142, [PT.disconnect]),
  topic_filter_invalid(143, [PT.suback, PT.unsuback, PT.disconnect]),
  topic_name_invalid(144, [PT.connack, PT.puback, PT.pubrec, PT.disconnect]),
  packet_id_in_use(145, [PT.puback, PT.pubrec, PT.suback, PT.unsuback]),
  packet_id_not_found(146, [PT.pubrel, PT.pubcomp]),
  receive_max_exceeded(147, [PT.disconnect]),
  topic_alias_invalid(148, [PT.disconnect]),
  packet_too_large(149, [PT.connack, PT.disconnect]),
  message_rate_too_high(150, [PT.disconnect]),
  quota_exceeded(151, [PT.connack, PT.puback, PT.pubrec, PT.suback, PT.disconnect]),
  administrative_action(152, [PT.disconnect]),
  payload_format_invalid(153, [PT.connack, PT.puback, PT.pubrec, PT.disconnect]),
  retain_not_supported(154, [PT.connack, PT.disconnect]),
  qos_not_supported(155, [PT.connack, PT.disconnect]),
  use_another_server(156, [PT.connack, PT.disconnect]),
  server_moved(157, [PT.connack, PT.disconnect]),
  shared_subscriptions_not_supported(158, [PT.suback, PT.disconnect]),
  connection_rate_exceeded(159, [PT.connack, PT.disconnect]),
  max_connect_time(160, [PT.disconnect]),
  subscription_ids_not_supported(161, [PT.suback, PT.disconnect]),
  wildcard_subscriptions_not_supported(162, [PT.suback, PT.disconnect])

  private new make(Int code, PT[] types := [,])
  {
    this.code  = code
    this.types = types
  }

  ** The reason code
  const Int code

  ** The packet types this code can be used for
  const PT[] types

  ** Is this an error reason code?
  Bool isErr() { code >= 128 }

  ** Get the MQTT 3.1.1 code
  Int v3()
  {
    if (code == 0) return 0
    switch (this)
    {
      // CONNACK
      case unsupported_protocol_version: return 1
      case client_identifier_not_valid:  return 2
      case server_unavailable:           return 3
      case bad_username_or_password:     return 4
      case not_authorized:               return 5

      // SUBACK
      case unspecified_error:            return 8
    }
    throw MqttErr("${this} ($code) does not map to a 3.1.1 reason code")
  }

  static ReasonCode? fromCode(Int code, PT type, Bool checked := true)
  {
    vals := ReasonCode.vals.findAll { it.code == code }
    val  := vals.findAll { it.types.contains(type) }
    if (val.size > 1) throw Err("Multiple codes matched ${code}: $val")
    if (val.size == 1) return val.first
    if (checked) throw ArgErr("No reason code for $type matches $code")
    return null
  }
}