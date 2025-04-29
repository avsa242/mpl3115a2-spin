{
----------------------------------------------------------------------------------------------------
    Filename:       sensor.baro.mpl3115a2.spin
    Description:    Driver for MPL3115A2 Pressure sensor with altimetry
    Author:         Jesse Burt
    Started:        Feb 1, 2021
    Updated:        Apr 28, 2025
    Copyright (c) 2025 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

#include "sensor.pressure.common.spinh"         ' use code common to all pressure/alt
#include "sensor.temp.common.spinh"             '   and temperature sensor drivers

CON

    { default I/O settings; these can be overridden in the parent object }
    SCL         = 28
    SDA         = 29
    I2C_FREQ    = 100_000
    I2C_ADDR    = 0


    SLAVE_WR    = core.SLAVE_ADDR
    SLAVE_RD    = core.SLAVE_ADDR|1
    I2C_MAX_FREQ= core.I2C_MAX_FREQ

' Operating modes
    SINGLE      = 0
    CONT        = 1

' Barometer/altitude modes
    BARO        = 0
    ALT         = 1


OBJ

{ decide: Bytecode I2C engine, or PASM? Default is PASM if BC isn't specified }
#ifdef MPL3115A2_I2C_BC
    i2c:    "com.i2c.nocog"                     ' BC I2C engine
#else
    i2c:    "com.i2c"                           ' PASM I2C engine
#endif
    core:   "core.con.mpl3115a2"                ' hw-specific constants
    time:   "time"                              ' basic timing functions
    u64:    "math.unsigned64"                   ' 64-bit unsigned int math


PUB null()
' This is not a top-level object


PUB start(): status
' Start using default I/O settings
    return startx(SCL, SDA, I2C_FREQ)


PUB startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start the driver with custom I/O settings
'   SCL_PIN:    I2C clock, 0..31
'   SDA_PIN:    I2C data, 0..31
'   I2C_HZ:     I2C clock speed (max official specification is 400_000 but is unenforced)
'   Returns:
'       cog ID+1 of I2C engine on success (= calling cog ID+1, if the bytecode I2C engine is used)
'       0 on failure
    if ( lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) )
        if ( status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ) )
            time.usleep(core.T_POR)             ' wait for device startup
            if ( dev_id() == core.DEVID_RESP )  ' validate device
                return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE


PUB stop()
' Stop the driver
    i2c.deinit()


PUB defaults()
' Set factory defaults
    reset()


PUB preset_active()
' Preset settings:
'   * set to power-on defaults and enable continuous sensor measurement
    reset()
    opmode(CONT)


PUB alt_baro_mode(m=-2): c | opmd_orig
' Set sensor to altimeter or barometer mode
'   Valid values:
'       BARO (0): Sensor outputs barometric pressure data
'       ALT (1): Sensor outputs altitude data
    c := readreg(core.CTRL_REG1)
    case m
        BARO, ALT:
            opmd_orig := (c & 1)                ' get current opmode
            ' must be in standby/SINGLE mode to set certain bits in this reg, so
            '   clear the opmode bit
            m := ( (c & core.ALT_MASK & core.SBYB_MASK) | (m << core.ALT) )
            writereg(core.CTRL_REG1, m)
            if (opmd_orig == CONT)              ' restore opmode, if it
                opmode(opmd_orig)               ' was CONT, previously
        other:
            return ((c >> core.ALT) & 1)


PUB alt_bias(o): c
' Get altitude bias/offset
'   Returns: meters
    c := readreg(core.OFF_H)
    return ~c                                   ' extend sign


PUB alt_data(): a
' Read altimeter data
'   NOTE: This is valid as altitude data _only_ if alt_baro_mode() is set to ALT (1)
    return readreg(core.OUT_P_MSB, 3)


PUB alt_set_bias(o)
' Set altitude bias/offset, in meters
'   Valid values: -128..127
    writereg(core.OFF_H, (-128 #> o <# 127) )   ' LSB = 1m


PUB altitude(): a
' Read altitude, in centimeters
'   NOTE: This is valid as altitude data _only_ if alt_baro_mode() is set to ALT (1)
    return alt_word2cm( alt_data() )


PUB alt_word2cm(w): a
' Convert altitude word to altitude, in centimeters
    return u64.multdiv(w, 100_00, 65536)        ' (adc word * 10,000) / 65536


PUB dev_id(): id
' Read device identification
'   Returns: $C4
    return readreg(core.WHO_AM_I)


PUB measure() | tmp
' Perform measurement
    tmp := readreg(core.CTRL_REG1)
    case opmode()
        SINGLE:
            tmp |= (1 << core.OST)              ' bit auto-clears in SINGLE
            writereg(core.CTRL_REG1, tmp)       '   mode
        CONT:
            tmp |= (1 << core.OST)
            writereg(core.CTRL_REG1, tmp)
            tmp &= core.OST_MASK                ' bit doesn't auto-clear in
            writereg(core.CTRL_REG1, tmp)       '   CONT mode; do it manually


PUB opmode(m=-2): c
' Set operating mode
'   Valid values:
'       SINGLE (0): Single-shot/standby
'       CONT (1): Continuous measurement
    c := readreg(core.CTRL_REG1)
    case m
        SINGLE, CONT:
            m := ( (c & core.SBYB_MASK) | m)
            writereg(core.CTRL_REG1, m)
        other:
            return (c & 1)


PUB oversampling(r=-2): c | opmd_orig
' Set output data oversampling ratio
'   Valid values: 1, 2, 4, 8, 16, 32, 64, 128 (default: 1)
'   Any other value polls the chip and returns the current setting
    c := readreg(core.CTRL_REG1)
    case r
        1..128:
            r := ( >|(r)-1 ) << core.OS         ' map 1..128 to bit 0..7
            opmd_orig := (c & 1)                ' get current opmode
            ' must be in standby/SINGLE mode to set certain bits in this reg, so
            '   clear the opmode bit
            r := ((c & core.OS_MASK & core.SBYB_MASK) | r)
            writereg(core.CTRL_REG1, r)
            if (opmd_orig == CONT)              ' restore opmode, if it
                opmode(opmd_orig)               ' was CONT, previously
        other:
            c := (c >> core.OS) & core.OS_BITS
            return |<(c)                        ' map bit 0..7 to 1..128


PUB press_bias(): o
' Get pressure bias/offset
'   Returns: Pascals
    o := readreg(core.OFF_P)
    return (~o * 4)                             ' extend sign


PUB press_data(): p
' Read pressure data
'   Returns: s20 (Q18.2 fixed-point)
'   NOTE: This is valid as pressure data _only_ if alt_baro_mode() is
'       set to BARO (0)
    return readreg(core.OUT_P_MSB, 3)


PUB press_data_rdy(): f
' dummy method for compatibility with other drivers
    return true


PUB press_set_bias(offs)
' Set pressure bias/offset, in Pascals
'   Valid values: -512..508 (clamped to range)
    offs := (-512 #> offs <# 508) / 4           ' LSB = 4Pa
    writereg(core.OFF_P, offs)


PUB press_word2pa(w): p
' Convert pressure ADC word to pressure in Pascals
    return ( (w * 100) / 640)


PUB reset() | tmp
' Reset the device
    tmp := (1 << core.RST)
    writereg(core.CTRL_REG1, tmp)
    time.usleep(core.T_POR)


PUB sea_lvl_press(): p
' Get sea-level pressure for altitude calculations
'   Returns: Pascals
    return readreg(core.BAR_IN_MSB, 2) << 1


PUB sea_lvl_set_press(p)
' Set sea-level pressure for altitude calculations, in Pascals
'   Valid values: 0..131_070 (clamped to range)
    p := (0 #> p <# 131_070) >> 1               ' LSB = 2Pa
    writereg(core.BAR_IN_MSB, p, 2)


PUB temp_bias(): o
' Get temperature bias/offset
'   Returns: ten-thousandths of a degree C
    o := readreg(core.OFF_T)
    return (~o * 0_0625)                        ' extend sign


PUB temp_data(): t
' Read temperature data
'   Returns: s12 (Q8.4 fixed-point)
    return readreg(core.OUT_T_MSB, 2)


PUB temp_set_bias(o)
' Set temperature bias/offset, in ten-thousandths of a degree C
    o := (-8_0000 #> o <# 7_9375) / 0_0625      ' LSB = 0.0625C
    writereg(core.OFF_T, o)


PUB temp_word2deg(w): t
' Calculate temperature from ADC word
'   w:          temperature ADC word
'   Returns:    temperature in hundredths of a degree in chosen scale

    ' extend sign, chop off reserved LSBs, scale up to hundredths
    '   divide down to scale to degrees C
    t := ( ( (~~w) ~> 4) * 100) / 16
    case _temp_scale
        C:
            return t
        F:
            return ((t * 9) / 5) + 32_00
        other:
            return FALSE


PRI readreg(reg_nr, len=1): v | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        core.STATUS..core.OFF_H:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            v := 0
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start()
            i2c.wr_byte(SLAVE_RD)
            i2c.rdblock_msbf(@v, len, i2c.NAK)
            i2c.stop()
            return
        other:                                  ' invalid reg_nr
            return


PRI writereg(reg_nr, val, len=1) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        core.F_SETUP, core.PT_DATA_CFG..core.OFF_H:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start()
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.wrblock_msbf(@val, len)
            i2c.stop()
        other:
            return


DAT
{
Copyright 2025 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

