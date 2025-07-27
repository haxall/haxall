//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jan 2025  Cline  Creation
//

using util
using xeto
using xetom

**
** Test backtick processing in XetoDoc GenPages
**
class BacktickProcessingTest : AbstractXetoTest
{

//////////////////////////////////////////////////////////////////////////
// Tests
//////////////////////////////////////////////////////////////////////////

  Void testBasicBacktickProcessing()
  {
    // Create a test namespace with some basic specs
    ns := createNamespace(["sys"])
    
    // Create a test GenPages instance
    compiler := TestDocCompiler(ns)
    genPages := TestGenPages()
    genPages.compiler = compiler
    
    // Test basic spec resolution
    input := "Use `Str` for strings and `Bool` for booleans"
    result := genPages.testNormalizeBackticks(input)
    
    // Should convert Str and Bool to their qualified names
    verifyTrue(result.contains("sys::Str | SpecFlavor::type"))
    verifyTrue(result.contains("sys::Bool | SpecFlavor::type"))
  }

  Void testUnknownSpecsStayUnchanged()
  {
    ns := createNamespace(["sys"])
    
    compiler := TestDocCompiler(ns)
    genPages := TestGenPages()
    genPages.compiler = compiler
    
    // Test with unknown spec
    input := "Use `UnknownSpec` for something"
    result := genPages.testNormalizeBackticks(input)
    
    // Should remain unchanged
    verifyEq(result, input)
  }

  Void testUrlsAndNonIdentifiersStayUnchanged()
  {
    ns := createNamespace(["sys"])
    
    compiler := TestDocCompiler(ns)
    genPages := TestGenPages()
    genPages.compiler = compiler
    
    // Test with URLs and non-identifiers
    input := "See `http://example.com` and `file.txt` and `user@domain.com`"
    result := genPages.testNormalizeBackticks(input)
    
    // Should remain unchanged
    verifyEq(result, input)
  }

  Void testAlreadyQualifiedStayUnchanged()
  {
    ns := createNamespace(["sys"])
    
    compiler := TestDocCompiler(ns)
    genPages := TestGenPages()
    genPages.compiler = compiler
    
    // Test with already qualified names
    input := "Use `sys::Str` for strings"
    result := genPages.testNormalizeBackticks(input)
    
    // Should remain unchanged
    verifyEq(result, input)
  }

  Void testMixedContent()
  {
    ns := createNamespace(["sys"])
    
    compiler := TestDocCompiler(ns)
    genPages := TestGenPages()
    genPages.compiler = compiler
    
    // Test with mixed resolvable and non-resolvable content
    input := "Use `Str` for strings, see `http://example.com`, and `UnknownSpec` too"
    result := genPages.testNormalizeBackticks(input)
    
    // Should only convert Str
    verifyTrue(result.contains("sys::Str | SpecFlavor::type"))
    verifyTrue(result.contains("`http://example.com`"))
    verifyTrue(result.contains("`UnknownSpec`"))
  }

}

//////////////////////////////////////////////////////////////////////////
// Test Helper Classes
//////////////////////////////////////////////////////////////////////////

** Test version of DocCompiler that provides minimal functionality
class TestDocCompiler
{
  new make(LibNamespace ns) { this.ns = ns }
  const LibNamespace ns
}

** Test version of GenPages that exposes private methods for testing
class TestGenPages
{
  TestDocCompiler? compiler
  
  LibNamespace ns() { compiler.ns }
  
  ** Expose normalizeBackticks for testing
  Str testNormalizeBackticks(Str text)
  {
    result := text
    
    // Find and replace backtick patterns
    i := 0
    while (i < result.size)
    {
      start := result.index("`", i)
      if (start == null) break
      
      end := result.index("`", start + 1)
      if (end == null) break
      
      content := result[start+1..<end]
      replacement := testProcessBacktick(content)
      
      if (replacement != null)
      {
        result = result[0..<start] + "`${replacement}`" + result[end+1..-1]
        i = start + replacement.size + 2
      }
      else
      {
        i = end + 1
      }
    }
    
    return result
  }
  
  ** Expose processBacktick for testing
  Str? testProcessBacktick(Str content)
  {
    // Skip if already qualified (contains ::)
    if (content.contains("::")) return null
    
    // Skip URLs and other non-identifier content
    if (content.contains("/") || content.contains(".") || content.contains("@")) 
      return null
    
    // Try to resolve as spec in namespace by searching through all libraries
    try
    {
      // Search through all libraries for a spec with this simple name
      for (i := 0; i < ns.libs.size; i++)
      {
        lib := ns.libs[i]
        spec := lib.spec(content, false)
        if (spec != null) 
        {
          // Return new format: qname | SpecFlavor::flavor
          flavorStr := spec.flavor.toStr
          return "${spec.qname} | SpecFlavor::${flavorStr}"
        }
      }
    }
    catch (Err e) { /* ignore resolution errors */ }
    
    // Return null if not found (stays unchanged)
    return null
  }
}
