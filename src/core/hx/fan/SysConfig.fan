//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Jun 2021  Brian Frank  Creation
//

using concurrent
using web
using xeto

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
  Obj? get(Str name) { meta.get(name) }

  ** Construct an service provider interface instance from given key
  Obj makeSpi(Str key)
  {
    qname := get(key) ?: throw Err("Boot config missing key: $key")
    return Type.find(qname).make
  }

  ** Is this a test system?
  virtual Bool isTest() { meta.has("test") }
}

