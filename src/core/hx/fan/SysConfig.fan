//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2021  Brian Frank  Creation
//

using xeto
using haystack
using util

**
** SysConfig models bootstrap configuration options
**
** NOTE: this API is subject to change
**
@NoDoc
const class SysConfig
{
  ** Construct with meta data dict
  new make(Dict meta) { this.metaRef = meta }

  ** Meta data
  virtual Dict meta() { metaRef }
  private const Dict metaRef

  ** Convenience for 'meta.has'
  Bool has(Str name) { meta.has(name) }

  ** Convenience for 'meta.get'
  @Operator Obj? get(Str name) { meta.get(name) }

  ** Construct a platform service provider interface instance from given key
  Obj makePlatformSpi(Ext ext, Str key)
  {
    qname := get(key) ?: throw Err("Boot config missing key: $key")
    spi := Type.find(qname).make
    spi.typeof.field("extRef")->setConst(spi, ext)
    return spi
  }

  ** Is this a test system?
  virtual Bool isTest() { meta.has("test") }

  ** Debug grid
  @NoDoc Grid debug()
  {
    gb := GridBuilder().addCol("name").addCol("val")
    meta.each |v, n| { gb.addRow2(n, v) }
    return gb.toGrid
  }

  ** Debug dump
  @NoDoc Void dump(Console con := Console.cur)
  {
    meta.each |v, n|
    {
      con.info("$n: $v")
    }
  }
}

