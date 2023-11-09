//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   1 Jul 2023  Brian Frank  Creation
//

using util
using xeto

**
** Load and assign a SpecFactory to each AType in the AST
**
internal class LoadFactories : Step
{
  override Void run()
  {
    // check if we need to install a new factor loader
    typeName := pragma.getStr("factoryLoader")
    if (typeName != null) env.factories.install(typeName)

    // find a loader for our library
    loader := env.factories.loaders.find |x| { x.canLoad(lib.name) }

    // if we have a loader, give it my type names to map to factories
    [Str:SpecFactory]? factories := null
    if (loader != null)
    {
      specNames := Str[,]
      lib.specs.each |spec|
      {
        specNames.add(spec.name)
      }
      factories = loader.load(lib.name, specNames)
    }

    // now assign factories to all type level types
    lib.specs.each |spec|
    {
      assignFactory(spec, factories)
    }
  }


  private Void assignFactory(ASpec spec, [Str:SpecFactory]? factories)
  {
    // lookup custom registered factory
    if (factories != null)
    {
      custom := factories[spec.name]
      if (custom != null)
      {
        spec.factoryRef = custom
        env.factories.map(custom.type, spec.qname, spec.asm)
        return
      }
    }

    // walk up type hiearchy looking for factory
    if (spec.ctype != null && !spec.ctype.isAst)
      spec.factoryRef = spec.ctype.factory

    // install default dict/scalar factory
    if (spec.factoryRef == null)
    {
      if (spec.isScalar)
        spec.factoryRef = env.factories.scalar
      else
        spec.factoryRef = env.factories.dict
    }
  }
}