//-------------------------------------
//
//  npm install -g ajv
//  npm install -g ajv-formats
//
//  $env:NODE_PATH=(npm root -g) ; node schema-test.js
//
//-------------------------------------

// load ajv
const Ajv = require('ajv').default; // Use .default for some module systems
const ajv = new Ajv();
const addFormats = require("ajv-formats")
addFormats(ajv)

// load schemas
ajv.addSchema(require('./sys.json'));
ajv.addSchema(require('./hx-test-xeto.json'));

// create product validator
const validateProduct = ajv.getSchema('hx.test.xeto-4.0.4#/$defs/Product');
//console.log(validateProduct)

// validate the instances
const instances = require('./instances.json');

Object.keys(instances).forEach(key => {
  const value = instances[key];

  console.log('------------------------------------------')
  console.log(value);

  valid = validateProduct(value)
  if (valid)
    console.log("OK!")
  else
    console.log(validateProduct.errors)
});
