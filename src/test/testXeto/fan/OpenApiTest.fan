//
// Copyright (c) 2026, Brian Frank
// All Rights Reserved
//
// History:
//   13 Feb 2026  Mike Jarmy
//

using yaml
using xeto
using xetom
using haystack

**
** OpenApiTest
**
class OpenApiTest : AbstractXetoTest
{
  Void testYaml()
  {
    obj := (YamlReader(exampleYaml.in).parse.decode as List)[0]

    buf := StrBuf()
    yw := YamlWriter(buf.out)
    yw.writeYaml(obj)
    result := buf.toStr
    verifyEq(result, exampleYaml)
  }

  private static const Str exampleYaml :=
    Str <|smart_home:
            location: Sector 7G
            security_system:
              status: Armed
              hardware:
                brand: GuardBot
                version: 2.4
            rooms:
              - devices:
                  - brightness: "75%"
                    state: On
                    type: Smart Light
                  - brand: Nest
                    type: Thermostat
                temperature: 22
                name: Living Room
              - devices:
                  - type: Smart Fridge
                    inventory:
                      - Milk
                      - Eggs
                      - Carrots
                temperature: 20
                name: Kitchen
         |>
}
