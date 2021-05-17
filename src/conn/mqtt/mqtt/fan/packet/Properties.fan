//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  27 Mar 2021   Matthew Giannini  Creation
//

using concurrent

**************************************************************************
** Properties
**************************************************************************

**
** Properties is a collection of MQTT property pairs.
**
const class Properties
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make() { }

  private const ConcurrentMap props := ConcurrentMap(8)

//////////////////////////////////////////////////////////////////////////
// Properties
//////////////////////////////////////////////////////////////////////////

  ** Add the given property and value pair. If the property already exists it is
  ** overwritten. However, the user property may be added multiple times.
  ** The value for the property is checked to ensure it is the correct type and
  ** fits the accepted range of values for that property.
  **
  ** If the val is 'null', all instances of the property are removed (including those
  ** that allow duplicate entries).
  This add(Property prop, Obj? val)
  {
    // check remove
    if (val == null) { props.remove(prop); return this }

    checkType(prop, val)
    checkRange(prop, val)

    if (prop === Property.userProperty)
    {
      // user property can appear multiple times and its order must be preserved
      StrPair[]? arr := props.get(prop)
      if (arr == null) arr = StrPair[,]
      props.set(prop, arr.rw.add(val).toImmutable)
    }
    else if (prop === Property.subscriptionId)
    {
      // the subscription identifier can appear multiple times (order is not significant)
      Int[]? arr := props.get(prop)
      if (arr == null) arr = Int[,]
      props.set(prop, arr.rw.add(val).toImmutable)
    }
    else
    {
      props.set(prop, val.toImmutable)
    }

    return this
  }

  ** Return if no properties are set.
  Bool isEmpty() { props.isEmpty }

  ** Get the value for the specified property, or return 'def' if it is not set.
  @Operator
  Obj? get(Property prop, Obj? def := null) { props.get(prop) ?: def }

  // TODO:FIXIT - if we need this capability then maybe want special
  // handling for props that can be repeated (user, subscription id)
  // ** Remove the value for this given property and return it.
  // Obj? remove(Property prop) { props.remove(prop) }

  ** Remove all properties and return this.
  This clear() { props.clear; return this }

  ** Iterate the properties.
  Void each(|Obj val, Property prop| f)
  {
    props.keys(Property#).sort.each |prop|
    {
      val := props[prop]
      if (val isnot List) f(val, prop)
      else
      {
        // iterate list vals in order
        (val as List).each |item| { f(item, prop) }
      }
    }
  }

  override Str toStr()
  {
    if (isEmpty) return "[]"

    buf := StrBuf().add("[\n")
    each |val, prop|
    {
      buf.add("  $prop = $val\n")
    }
    return buf.add("]").toStr
  }

//////////////////////////////////////////////////////////////////////////
// Convenience
//////////////////////////////////////////////////////////////////////////

  internal Int maxPacketSize() { get(Property.maxPacketSize, Int.maxVal) }

  internal Duration? messageExpiryInterval()
  {
    secs := get(Property.messageExpiryInterval)
    if (secs == null) return null
    return Duration.fromStr("${secs}sec")
  }

  internal QoS maxQoS() { QoS.vals[(Int)get(Property.maxQoS, 2)] }

  internal Str? reasonStr() { get(Property.reasonStr) }

  internal Int receiveMax() { get(Property.receiveMax, 65_535) }

  internal Bool retainAvailable() { get(Property.retainAvailable, 1) == 1 }

  internal Int[] subscriptionIds() { get(Property.subscriptionId, Int#.emptyList) }

  internal StrPair[] userProps() { get(Property.userProperty, StrPair#.emptyList) }

  internal Bool utf8Payload() { get(Property.payloadFormatIndicator, 0) == 1 }

  internal Bool wildcardSubscriptionAvailable() { get(Property.wildcardSubscriptionAvailable, 1) == 1 }


//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Void checkType(Property prop, Obj val)
  {
    ok := true
    switch (prop.type)
    {
      case DataType.byte:
      case DataType.byte2:
      case DataType.byte4:
      case DataType.vbi:
        ok = val is Int
      case DataType.utf8:
        ok = val is Str
      case DataType.binary:
        ok = val is Buf
      case DataType.strPair:
        ok = val is StrPair
      default:
        throw ArgErr("Unexpected property: $prop [$prop.type]")
    }
    if (!ok) throw ArgErr("${prop} must be ${prop.type}: $val (${val.typeof})")
  }

  private Void checkRange(Property prop, Obj val)
  {
    ok := true

    // data type range checks
    switch (prop.type)
    {
      case DataType.byte:
        ok = 0 <= val && val <= 0xFF
      case DataType.byte2:
        ok = 0 <= val && val <= 0xFFFF
      case DataType.byte4:
        ok = 0 <= val && val <= 0xFFFF_FFFF
    }

    // special range checks
    switch (prop)
    {
      case Property.maxPacketSize:
      case Property.receiveMax:
      case Property.topicAlias:
        // fall-through
        ok = val != 0

      case Property.maxQoS:
      case Property.payloadFormatIndicator:
      case Property.requestResponseInfo:
      case Property.sharedSubscriptionAvailable:
      case Property.subscriptionIdsAvailable:
      case Property.wildcardSubscriptionAvailable:
        // fall-through
        ok = val == 0 || val == 1

      case Property.subscriptionId:
        ok = MqttConst.minSubId <= val && val <= MqttConst.maxSubId
    }

    if (!ok) throw ArgErr("Value out-of-range for $prop: $val")
  }
}

**************************************************************************
** Property
**************************************************************************

**
** Property types
**
enum class Property
{
  payloadFormatIndicator(1, DataType.byte),
  messageExpiryInterval(2, DataType.byte4),
  contentType(3, DataType.utf8),
  responseTopic(8, DataType.utf8),
  correlationData(9, DataType.binary),
  subscriptionId(11, DataType.vbi),
  sessionExpiryInterval(17, DataType.byte4),
  assignedClientId(18, DataType.utf8),
  serverKeepAlive(19, DataType.byte2),
  authMethod(21, DataType.utf8),
  authData(22, DataType.binary),
  requestProblemInfo(23, DataType.byte),
  willDelayInterval(24, DataType.byte4),
  requestResponseInfo(25, DataType.byte),
  responseInfo(26, DataType.utf8),
  serverRef(28, DataType.utf8),
  reasonStr(31, DataType.utf8),
  receiveMax(33, DataType.byte2),
  topicAliasMax(34, DataType.byte2),
  topicAlias(35, DataType.byte2),
  maxQoS(36, DataType.byte),
  retainAvailable(37, DataType.byte),
  userProperty(38, DataType.strPair),
  maxPacketSize(39, DataType.byte4),
  wildcardSubscriptionAvailable(40, DataType.byte),
  subscriptionIdsAvailable(41, DataType.byte),
  sharedSubscriptionAvailable(42, DataType.byte)

  private new make(Int id, DataType type)
  {
    this.id   = id
    this.type = type
  }

  static Property fromId(Int id) { Property.vals.find { it.id == id } }

  ** Property id (these do *not* map to ordinal position)
  const Int id

  ** How the property should be encoded
  const DataType type

  override Str toStr() { "Property(name: ${name}, id: 0x${id.toRadix(16,2)}, type: ${type})" }
}

**************************************************************************
** StrPair
**************************************************************************

**
** StrPair models the MQTT UTF-8 String Pair data type. This data type
** is used to hold hame-value pairs.
**
final const class StrPair
{
  new make(Str name, Str val)
  {
    this.name  = name
    this.val   = val
  }

  const Str name

  const Str val

  override Int hash() { "$name$val".hash }

  override Bool equals(Obj? obj)
  {
    if (this === obj) return true
    that := obj as StrPair
    if (that == null) return false
    return this.name == that.name && this.val == that.val
  }

  override Str toStr() { "$name=$val" }
}
