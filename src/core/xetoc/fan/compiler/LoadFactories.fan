//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using util
using xeto
using haystack
using xetoEnv

**
** Load and assign a SpecFactory to each AType in the AST
**
internal class LoadFactories : Step
{
  override Void run()
  {
    // check if we need to install a new factor loader
    podName := pragma.getStr("fantomPodName")
    if (podName != null)
    {
      // just pass thru meta required by loader
      loadLibMeta := Etc.dict1("fantomPodName", podName)
      factories.install(lib.name, loadLibMeta)
    }

    // find a loader for our library
    loader := factories.loader(lib.name)

    // if we have a loader, give it my type names to map to factories
    [Str:SpecFactory]? customs := null
    if (loader != null)
    {
      specNames := Str[,]
      lib.tops.each |spec|
      {
        specNames.add(spec.name)
      }
      customs = loader.load(lib.name, specNames)
    }

    // now assign factories to all type level types
    lib.tops.each |spec|
    {
      assignFactory(spec, customs)
    }
  }


  private Void assignFactory(ASpec spec, [Str:SpecFactory]? customs)
  {
    // lookup custom registered factory
    if (customs != null)
    {
      custom := customs[spec.name]
      if (custom != null)
      {
        spec.factoryRef = custom
        factories.map(custom.type, spec.qname)
        return
      }
    }

    // walk up type hiearchy looking for factory
//    if (!spec.ctype.isAst)
//      spec.factoryRef = spec.ctype.factory

    // install default dict/scalar factory
    if (spec.factoryRef == null)
    {
      if (spec.isScalar)
        spec.factoryRef = GenericScalarFactory(spec.ctype.qname)
      else
        spec.factoryRef = factories.dict
    }
  }
}

