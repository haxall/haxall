//-------------------------------------
//
//  npm install -g ajv
//  npm install -g ajv-formats
//
//  $env:NODE_PATH=(npm root -g) ; node schema-test.js
//
//-------------------------------------

const Ajv = require("ajv")
const addFormats = require("ajv-formats")

const ajv = new Ajv({allErrors: true})
addFormats(ajv)

//----------------------------------------------------------

const schema = {
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "http://example.com/ecommerce-library.schema.json",
  "title": "Ecommerce Data Library",
  "description": "A collection of schema definitions for common e-commerce objects.",

  "$ref": "#/definitions/Order",

  "definitions": {

    // --- NEW: Order ID Definition ---
    "orderId": {
      "type": "string",
      "description": "A unique, patterned identifier for a sales order.",
      // Enforces the format, e.g., ORD-2025-12345
      "pattern": "^ORD-[0-9]{4}-[0-9]+$"
    },

    "Product": {
      "type": "object",
      "title": "Product Item",
      "properties": {
        "product_id": {
          "type": "integer",
          "description": "The unique identifier for a product."
        },
        "product_name": {
          "type": "string",
          "description": "Name of the product."
        },
        "price": {
          "type": "number",
          "exclusiveMinimum": 0
        }
      },
      "required": ["product_id", "product_name", "price"]
    },

    "Order": {
      "type": "object",
      "title": "Sales Order",
      "properties": {
        "order_id": {
          // --- UPDATED: Reference the new definition ---
          "$ref": "#/definitions/orderId"
        },
        "customer_name": {
          "type": "string"
        },
        "items": {
          "type": "array",
          "description": "The list of products in the order.",
          "minItems": 1,
          "items": {
            "$ref": "#/definitions/Product"
          }
        },
        "order_date": {
          "type": "string",
          "format": "iso-date-time"
        }
      },
      "required": ["order_id", "items", "order_date"]
    }
  }
}

const validateSchema = ajv.compile(schema)

//----------------------------------------------------------

const data = {
  "order_id": "ORD-2025-00101",
  "customer_name": "Frodo Baggins",
  "order_date": "2025-12-16T13:40:00Z",
  "items": [
    {
      "product_id": 9001,
      "product_name": "Deluxe Blender",
      "price": 89.99
    },
    {
      "product_id": 9002,
      "product_name": "Toaster Oven",
      "price": 45.00
    },
    {
      "product_id": 9003,
      "product_name": "Electric Kettle",
      "price": 29.50
    }
  ]
}

var valid = validateSchema(data)
if (valid)
  console.log("OK!")
else
  console.log(validateSchema.errors)

//----------------------------------------------------------

const bogus = {
  "customer_name": "Bob Smith",
  "items": [
    {
      "product_id": 500,
      "product_name": "Pen Set",
      "price": -5.00  // ERROR 1: Price cannot be less than 0
    }
  ]
  // ERROR 2: 'order_id' is missing (It is required in the Order definition)
  // ERROR 3: 'order_date' is missing (It is required in the Order definition)
}

valid = validateSchema(bogus)
if (valid)
  console.log("OK!")
else
  console.log(validateSchema.errors)
