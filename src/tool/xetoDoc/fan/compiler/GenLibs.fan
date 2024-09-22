//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

**
** Generate the DocLib instances
**
internal class GenLibs : Step
{
  override Void run()
  {
    eachLib |lib|
    {
      d := genLib(lib)
echo
echo
JsonDocWriter(Env.cur.out).writeLib(d)
    }
  }

  DocLib genLib(Lib lib)
  {
    DocLib {
      it.id        = this.id(lib.name)
      it.name      = lib.name
      it.meta      = genLibMeta(lib.meta)
      it.types     = lib.types.map |x->DocSummary| { summary(x.qname) }
      it.globals   = lib.globals.map |x->DocSummary| { summary(x.qname) }
      it.instances = lib.instances.map |x->DocSummary| { summary(x._id.toStr) }
    }
  }

  DocLibMeta genLibMeta(Dict meta)
  {
    DocLibMeta(meta)
  }
}

