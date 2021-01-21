module.exports = {
  title: "pimatic-ina219 device config schemas"
  Ina219Device: {
    title: "Ina219Device config options"
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
        enum: [0x40,0x41,0x44,0x45]
        default: 0x40
      interval:
        interval: "Sensor read interval in ms"
        type: "integer"
        default: 10000
    }
  }
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
      forwardPowerChannel: "Channel of the forwardPower sensor (1..4)"
        type: "number"
        default: 1
      reflectedPowerChannel: "Channel of the reflectedPower sensor (1..4)"
        type: "number"
        default: 2
      gain: ""
        type: "string"
        enum: ["x1","x2","x4","x8"]
        default: "x1"
      resolution: ""
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
