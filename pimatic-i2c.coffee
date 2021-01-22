module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  #M = env.matcher
  #_ = require('lodash')
  #ina219 = require('ina219')
  MCP3424 = require('./adapters/mcp3424.js')

  class I2cPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-i2c-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      #@framework.deviceManager.registerDeviceClass('Ina219Device', {
      #  configDef: @deviceConfigDef.Ina219Device,
      #  createCallback: (config, lastState) => new Ina219Device(config, lastState, @config.debug)
      #})
      @framework.deviceManager.registerDeviceClass('Mcp3424Device', {
        configDef: @deviceConfigDef.Mcp3424Device,
        createCallback: (config, lastState) => new Mcp3424Device(config, lastState, @config.debug, @)
      })

  ###
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
  ###

  class Mcp3424Device extends env.devices.Device

    constructor: (config, lastState, logging, plugin) ->
      @config = config
      @id = @config.id
      @name = @config.name

      @interval = @config.interval ? 10000
      @address = @config.address ? 0x40
      _device = @config.device  ? 1
      @device = _device
      @channels = @config.channels

      #env.logger.debug "@deviceConfigDef.Mcp3424Device: " + JSON.stringify(plugin.deviceConfigDef.Mcp3424Device.properties.gain,null,2)

      # gain: [0,1,2,3] = [x1,x2,x4,x8]
      switch @config.gain
        when "x8"
          @gain = 3
        when "x4"
          @gain = 2
        when "x2"
          @gain = 1
        else
          @gain = 0

      # resolution: [0,1,2,3] = [12,14,16,18] bits
      switch @config.resolution
        when 18
          @resolution = 3
        when 16
          @resolution = 2
        when 14
          @resolution = 1
        else
          @resolution = 0

      @channelValues = {}
      @attributes = {}
      for channel in @channels
        env.logger.debug "Channel: " + JSON.stringify(channel,null,2)
        @attributes[channel.name] =
          description: channel.name
          type: "number"
          unit: channel.unit ? ""
          acronym: channel.acronym ? ""
        @channelValues[channel.name] = lastState?[channel.name]?.value ? 0
        @_createGetter channel.name, () =>
          return Promise.resolve @channelValues[channel.name]

      env.logger.debug "I2c start mcp3424"

      MCP3424.enableLogging(true)
      MCP3424.init(@address, @gain, @resolution, @device)

      requestValues = () =>
        env.logger.debug "Requesting mcp3424 sensor values"
        try
          for channel in @channels
            @channelValues[channel.name] = MCP3424.getMv(channel.channel)
            @emit channel.name, @channelValues[channel.name]
        catch err
          env.logger.debug "Error getting mcp3424 sensor values: #{err}"

        @requestValueIntervalId = setTimeout( requestValues, @interval)

      requestValues()

      super()

    destroy:() =>
      clearInterval(@requestValueIntervalId)
      super()


  i2cPlugin = new I2cPlugin
  return i2cPlugin
