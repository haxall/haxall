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

// create validators
validateOrder   = ajv.getSchema('hx.test.xeto-4.0.4#/$defs/Order')
validateProduct = ajv.getSchema('hx.test.xeto-4.0.4#/$defs/Product')

// validate the instances
const instances = require('./instances.json');

Object.keys(instances).forEach(key => {
  const value = instances[key];

  console.log('------------------------------------------')
  console.log(value.spec);

  switch (value.spec)
  {
    case "hx.test.xeto::Order":
      doValidate(validateOrder, value);
      break;
    case "hx.test.xeto::Product":
      doValidate(validateProduct, value);
      break;
    default:
      throw Err('Cannot validate ' + value.spec);
  }

});

function doValidate(func, value) {
  valid = func(value);
  if (valid)
    console.log("OK!")
  else
    console.log(func.errors)
}
