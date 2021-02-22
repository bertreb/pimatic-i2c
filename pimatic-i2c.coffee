module.exports = (env) ->
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  #M = env.matcher
  #_ = require('lodash')
  #ina219 = require('ina219')
  MCP3424 = require('./adapters/ReadADC_i2c.js')

  class I2cPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>

      pluginConfigDef = require './pimatic-i2c-config-schema'

      @deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass('Mcp3424Device', {
        configDef: @deviceConfigDef.Mcp3424Device,
        createCallback: (config, lastState) => new Mcp3424Device(config, lastState, @config.debug, @)
      })

  class Mcp3424Device extends env.devices.Device

    constructor: (config, lastState, logging, plugin) ->
      @config = config
      @id = @config.id
      @name = @config.name

      @address = (if @config.address? then @config.address else "0x68")
      env.logger.debug "Used address is " + @address
      @channels = @config.channels
      @nrOfChannels = @config.channels.length
      @activeChannels = []

      env.logger.debug "Config interval: " + @config.interval
      @int = if @config.interval? then @config.interval else 5000

      # gain: [0,1,2,3] = [x1,x2,x4,x8]
      switch @config.gain
        when "x8"
          @gain = 8
        when "x4"
          @gain = 4
        when "x2"
          @gain = 2
        else
          @gain = 1


      # resolution: [0,1,2,3] = [12,14,16,18] bits
      switch @config.resolution
        when 18
          @resolution = 18
        when 16
          @resolution = 16
        when 14
          @resolution = 14
        else
          @resolution = 12

      #check if channel is only used once
      _channelAdded = {}
      for channel, i in @config.channels
        if _channelAdded[channel.channel]? then throw new Error("Channel #{channel.channel} is already added")
        _channelAdded[channel.channel] = channel.channel
        if channel.multiplier <= 0 then throw new Error("Channel: #{channel.channel}, multiplier: #{channel.multiplier} is invalid")
        @config.channels[i]["multiplier"] = @config.channels[i].multiplier ? 1
        @config.channels[i]["offset"] = @config.channels[i].offset ? 0

      @channelValues = {}
      @attributes = {}
      for channel in @channels
        env.logger.debug "Channel: " + JSON.stringify(channel,null,2)
        @attributes[channel.name] =
          description: channel.name
          type: "number"
          unit: channel.unit ? ""
          acronym: channel.acronym ? channel.name
        @channelValues[channel.name] = lastState?[channel.name]?.value ? 0
        @_createGetter channel.name, () =>
          return Promise.resolve @channelValues[channel.name]
        @activeChannels.push channel.channel

      env.logger.debug "I2c start mcp3424 " + @int #+ JSON.stringify(MCP3424,null,2)

      #init channels

      env.logger.debug "@activeChannels: " + @activeChannels

      if @activeChannels.length > 0

        MCP3424.setup(parseInt(@address), @activeChannels)

        for channel in @config.channels
          MCP3424.setOpt(channel.channel,'gain',@gain)
          MCP3424.setOpt(channel.channel,'bits',@resolution)

        readChannel = (channel) =>
          result = MCP3424.readChannel(channel.channel)
          env.logger.debug "Result #{channel.channel}: " + JSON.stringify(result,null,2)
          @channelValues[channel.name] = channel.offset + result.adcV * channel.multiplier
          if @channelValues[channel.name] < 0 then @channelValues[channel.name] = 0
          @emit channel.name, @channelValues[channel.name]

        requestValues = () =>
          env.logger.debug "Requesting mcp3424 sensor values"
          if @nrOfChannels > 0 and @config.channels[0].channel is 1
            readChannel(@config.channels[0])
          if @nrOfChannels > 1 and @config.channels[1].channel is 2
            readChannel(@config.channels[1])
          if @nrOfChannels > 2 and @config.channels[2].channel is 3
            readChannel(@config.channels[2])
          if @nrOfChannels > 3 and @config.channels[3].channel is 4
            readChannel(@config.channels[3])
          @requestValueIntervalId = setTimeout( requestValues, @int)

        requestValues()

      super()

    destroy:() =>
      clearInterval(@requestValueIntervalId)
      super()


  i2cPlugin = new I2cPlugin
  return i2cPlugin
