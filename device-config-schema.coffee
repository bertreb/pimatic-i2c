module.exports = {
  title: "pimatic-i2c device config schemas"
  Mcp3424Device: {
    title: "Mcp3424Device config options"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:{
      device:
        description: "Device file to use (prefix /dev/i2c- is automatically added)"
        type: "number"
        default: 1
      address:
        description: "Address of the sensor"
        type: "number"
        default: 0x68
      channels:
        description: "Input channel attributes"
        type: "array"
        items:
          type: "object"
          properties:
            channel:
              description: "channel number"
              type: "number"
              enum: [1,2,3,4]
            name:
              description: "channel attribute name"
              type: "string"
            unit:
              description: "channel unit"
              type: "string"
              required: false
            acronym:
              description: "channel acronym"
              type: "string"
              required: false
      gain:
        type: "string"
        enum: ["x1","x2","x4","x8"]
        default: "x1"
      resolution:
        type: "number"
        enum: [12,14,16,18]
        default: 12
      interval:
        interval: "Sensor read interval in ms"
        type: "integer"
        default: 10000
    }
  }
}
