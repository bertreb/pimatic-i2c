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
        description: "Address of the mcp3424 sensor"
        type: "string"
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
            multiplier:
              description: "Multiplier for adjusting input value"
              type: "number"
              default: 1
            offset:
              description: "Offset for adjusting input value"
              type: "number"
              default: 0
            unit:
              description: "channel unit"
              type: "string"
              required: false
            acronym:
              description: "channel acronym"
              type: "string"
              required: false
      gain:
        description: "Sensor gain"
        type: "string"
        enum: ["x1","x2","x4","x8"]
        default: "x1"
      resolution:
        description: "Sensor resolution"
        type: "number"
        enum: [12,14,16,18]
        default: 12
      interval:
        description: "Sensor read interval in ms"
        type: "number"
        default: 10000
    }
  }
}
