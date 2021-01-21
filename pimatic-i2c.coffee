module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher
  _ = require('lodash')
  ina219 = require('ina219')
  mcp3424 = require('./adapters/mcp3424.js')

  class I2cPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-ina219-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass('Ina219Device', {
        configDef: @deviceConfigDef.Ina219Device,
        createCallback: (config, lastState) => new Ina219Device(config, lastState, @config.debug)
      })
      @framework.deviceManager.registerDeviceClass('Mcp3424Device', {
        configDef: @deviceConfigDef.Mcp3424Device,
        createCallback: (config, lastState) => new Mcp3424Device(config, lastState, @config.debug)
      })

  class Ina219Device extends env.devices.Device

    attributes:
      voltage:
        description: "Voltage"
        type: "number"
        unit: 'V'
        acronym: 'V'
      current:
        description: "Current"
        type: "number"
        unit: 'A'
        acronym: 'A'

    constructor: (config, lastState, logging) ->
      @config = config
      @id = @config.id
      @name = @config.name

      @interval = @config.interval ? 10000
      @address = @config.address ? 0x40
      @device = @config.device ? 1

      @_voltage = lastState?.voltage?.value
      @_current = lastState?.current?.value

      ina219.init(@address, @device)
      ina219.enableLogging(logging)

      requestValues = () =>
        env.logger.debug "Requesting sensor values"
        try
          ina219.getBusVoltage_V((_volts) =>
            if Number.isNaN(_volts) then _volts = 0
            env.logger.debug "Voltage (V): " + _volts
            @emit "voltage", _volts
            ina219.getCurrent_mA((_current) =>
              if Number.isNaN(_current) then _current = 0
              env.logger.debug "Current (mA): " + _current
              @emit "current", _current / 1000
            )
          )
        catch err
          env.logger.debug "Error getting sensor values: #{err}"

      ina219.calibrate32V1A(() => # kan ook ina219.calibrate32V2A
        requestValues()
        @requestValueIntervalId = setInterval( requestValues, @interval)
      )

      super()

    getVoltage: -> Promise.resolve(@_voltage)
    getCurrent: -> Promise.resolve(@_current)

    destroy:() =>
      clearInterval(@requestValueIntervalId)
      super()

  class Mcp3424Device extends env.devices.Device

    attributes:
      forwardPower:
        description: "Forward Power"
        type: "number"
        unit: 'W'
        acronym: 'FP'
      reflectedPower:
        description: "Reflected Power"
        type: "number"
        unit: 'W'
        acronym: 'RP'

    constructor: (config, lastState, logging) ->
      @config = config
      @id = @config.id
      @name = @config.name

      @interval = @config.interval ? 10000
      @address = @config.address ? 0x40
      _device = @config.device  ? 1
      @device = '/dev/i2c-' + _device

      @forwardPowerChannel = @config.forwardPowerChannel ? 1
      @reflectedPowerChannel = @config.reflectedPowerChannel ? 2

      env.logger.debug "@deviceConfigDef.Mcp3424Device: " + JSON.stringify(@deviceConfigDef.Mcp3424Device,null,2)

      # gain: [0,1,2,3] = [x1,x2,x4,x8]
      # resolution: [0,1,2,3] = [12,14,16,18] bits

      @gain = _.indexOf(@deviceConfigDef.Mcp3424Device.gain.default, @config.gain) ? 0
      @resolution = _.indexOf(@deviceConfigDef.Mcp3424Device.resolution.default, @config.resolution) ? 3

      @_forwardPower = lastState?.forwardPower?.value
      @_reflectedPower = lastState?.reflectedPower?.value

      mcp = new mcp3424(@address, @gain, @resolution, @device)

      requestValues = () =>
        env.logger.debug "Requesting sensor values"
        try
          @_forwardPower = mcp.getVoltage(@forwardPowerChannel)
          @emit 'forwardPower', @_forwardPower
          @_reflectedPower = mcp.getVoltage(@reflectedPowerChannel)
          @emit 'reflectedPower', @_reflectedPower
        catch err
          env.logger.debug "Error getting sensor values: #{err}"

        @requestValueIntervalId = setInterval( requestValues, @interval)
      
      requestValues()

      super()

    getForwardPower: -> Promise.resolve(@_forwardPower)
    getReflectedPower: -> Promise.resolve(@_reflectedPower)

    destroy:() =>
      clearInterval(@requestValueIntervalId)
      super()


  ina219Plugin = new Ina219Plugin
  return ina219Plugin
