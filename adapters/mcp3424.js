"use strict";
/*
 * Node driver for MCP3424
 */
var i2c = require('i2c-bus');  // https://github.com/fivdi/i2c-bus

/**
 * Mcp3424 is the main class exported from the Node module
 *
 */
var MCP3424 = function() {}


/**
 * Callback for standard oncomplete
 *
 * @callback onCompleteCallback
 */

/**
 * Callback for returning a single value
 *
 * @callback onHaveValueCallback
 * @param {int} value - value returned by async operation 
 */

// ===========================================================================
//   I2C Values
// ==========================================================================

var MCP342X_ADDRESS     = 0x00  ; // default address
// ===========================================================================
var MCP342X_RES_SHIFT       = 2  ;
var MCP342X_RES_FIELD       = 0x0C  ;

var MCP342X_GAIN_FIELD      = 0x03  ; // Gain field
var MCP342X_GAIN_X1         = 0x00  ; // Gain 1
var MCP342X_GAIN_X2         = 0x01  ; // Gain 2
var MCP342X_GAIN_X4         = 0x02  ; // Gain 4
var MCP342X_GAIN_X8         = 0x03  ; // Gain 8

var MCP342X_12_BIT          = 0x00  ; // 12 bit Resolution Mask
var MCP342X_14_BIT          = 0x04  ; // 14 bit Resolution Mask
var MCP342X_16_BIT          = 0x08  ; // 16 bit Resolution Mask
var MCP342X_18_BIT          = 0x0C  ; // 18 bit Resolution Mask

var MCP342X_CHANNEL_1       = 0x00  ; // channel 1
var MCP342X_CHANNEL_2     = 0x20  ; // channel 2
var MCP342X_CHANNEL_3     = 0x40  ; // channel 3
var MCP342X_CHANNEL_4     = 0x60  ; // channel 4

var MCP342X_START                 = 0x80  ; // Operating Mode Mask
var MCP342X_BUSY      = 0x80;
var MCP3424 ;



/**
  * Called to initilize the MCP3424.
  * @param {string} address - Address you want to use. Defaults to MCP342X_ADDRESS
  * @param {integer} gain 
  * @param {integer} resolution
  * @param {integer} busNumber - the number of the I2C bus/adapter to open, 0 for /dev/i2c-0, 1 for /dev/i2c-1, (See github.com/fivdi/i2c-bus)
  */
MCP3424.prototype.init = function (address, gain, resolution, busNumber) {

  // defaults
  address = typeof address !== 'undefined' ? address : MCP342X_ADDRESS;
  busNumber = typeof busNumber !== 'undefined' ? busNumber : 1;
  
  this.log("init:: " + address + " | " + busNumber)
  this.resolution = resolution;
  this.gain = gain;
  this.channel = [];
  this.currChannel = 0;
  this.address = address;
  
  this.wire = i2c.openSync(busNumber);

  this._readDataContiuously();
}

/**
  * Enabled debug logging to console.log
  * @param {bool} enable - True to enable, False to disable
  */
MCP3424.prototype.enableLogging  = function (enable) {

  this.loggingEnabled = enable;
}

MCP3424.prototype.getMv = function(chan) {
    return this.channel[chan];
};

MCP3424.prototype.getVoltage = function(chan) {
    return ((this.getMv(chan) * (0.0005 / this._getPga())) * 2.471)
};

MCP3424.prototype._getMvDivisor = function() {
    var mvDivisor;
    return mvDivisor = 1 << (this.gain + 2 * this.res);
};

MCP3424.prototype._getAdcConfig = function(chan) {
    var adcConfig;
    adcConfig = MCP342X_CHANNEL_1 | MCP342X_CONTINUOUS;
    return adcConfig |= chan << 5 | this.res << 2 | this.gain;
};

MCP3424.prototype._changeChannel = function(chan) {
    var command;
    command = this._getAdcConfig(chan);
    return this.wire.writeByte(command, function(err) {
        if (err !== null) {
            return console.log(err);
        }
    });
};

MCP3424.prototype._readDataContiuously = function() {
    var self;
    self = this;
    return setInterval((function() {
        self._readData(self.currChannel);
    }), 5000); //was 10
};

MCP3424.prototype._nextChannel = function() {
    this.currChannel++;
    if (this.currChannel === 4) {
        return this.currChannel = 0;
    }
};

MCP3424.prototype._readData = function(chan) {
    var adcConfig, result, self, statusByte;
    self = this;
    adcConfig = this._getAdcConfig(chan);
    result = 0;
    statusByte = 0;
    return this.wire.readBytes(adcConfig, 4, function(err, res) {
        var byte0, byte1, byte2;
        if (err !== null) {
            console.log(err);
        }
        if ((adcConfig & MCP342X_RES_FIELD) === MCP342X_18_BIT) {
            byte0 = res[0];
            byte1 = res[1];
            byte2 = res[2];
            statusByte = res[3];
            result = byte2 | byte1 << 8 | byte0 << 16;
        } else {
            byte0 = res[0];
            byte1 = res[1];
            statusByte = res[2];
            result = byte1 | byte0 << 8;
        }
        if ((statusByte & MCP342X_BUSY) === 0) {
            self.channel[self.currChannel] = result / self._getMvDivisor();
            self._nextChannel();
            return self._changeChannel(self.currChannel);
        } else {
            return "err";
        }
    });
};

MCP3424.prototype._getPga = function() {
    var gain = this.gain;

    if (gain == MCP342X_GAIN_X1) {
        return 0.5;
    }

    if (gain == MCP342X_GAIN_X2) {
        return 1;
    }

    if (gain == MCP342X_GAIN_X4) {
        return 2;
    }

    if (gain == MCP342X_GAIN_X8) {
        return 4;
    }
};

// return MCP3424;

  
// export is a Singleton
module.exports = MCP3424;

