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
** Generate ids for every top-level node indexed by qname
**
internal class GenIds : Step
{
  override Void run()
  {
    acc := Str:DocId[:]
    eachLib |lib|
    {
      // lib id
      acc.add(lib.name, libId(lib))

      // type ids
      lib.types.each |x|
      {
        acc.add(x.qname, typeId(lib, x))
      }

      // globals ids
      lib.globals.each |x|
      {
        acc.add(x.qname, globalId(lib, x))
      }

      // instance ids
      lib.instances.each |x|
      {
        qname := x._id.id
        name := XetoUtil.qnameToName(qname)
        acc.add(qname, instanceId(lib, name))
      }
    }
    compiler.ids = acc
  }

  DocId libId(Lib lib)
  {
    DocId(DocNodeType.lib, `$lib.name`, lib.name)
  }

  DocId typeId(Lib lib, Spec x)
  {
    DocId(DocNodeType.type, `$lib.name/$x.name`, x.name)
  }

  DocId globalId(Lib lib, Spec x)
  {
    DocId(DocNodeType.global, `$lib.name/$x.name`, x.name)
  }

  DocId instanceId(Lib lib, Str name)
  {
    DocId(DocNodeType.instance, `$lib.name/$name`, name)
  }
}

