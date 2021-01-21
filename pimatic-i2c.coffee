module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  M = env.matcher
  _ = require('lodash')
  mcp3424 = require('./adapters/mcp3424.js')

  class I2cPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-ina219-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass('Mcp3424Device', {
        configDef: @deviceConfigDef.Mcp3424Device,
        createCallback: (config, lastState) => new Mcp3424Device(config, lastState, @config.debug)
      })


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
