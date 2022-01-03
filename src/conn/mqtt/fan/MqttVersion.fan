//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  01 Apr 2021   Matthew Giannini  Creation
//

**
** MQTT protocol revision
**
enum class MqttVersion
{
  v3_1_1(4),
  v5(5)

  private new make(Int code) { this.code = code }

  static MqttVersion? fromCode(Int code, Bool checked := true)
  {
    ver := MqttVersion.vals.find { it.code == code }
    if (ver != null) return ver
    if (checked) throw ArgErr("No version matching code: $code")
    return null
  }

  ** The one byte value that represents the protocol revision.
  const Int code

  override Str toStr()
  {
    switch (code)
    {
      case 4: return "3.1.1"
      case 5: return "5.0"
    }
    throw Err("Unknown version: $code")
  }

  ** Is this version 3.1.1
  Bool is311() { this === v3_1_1 }

  ** Is this version 5.0
  Bool is5() { this === v5 }
}