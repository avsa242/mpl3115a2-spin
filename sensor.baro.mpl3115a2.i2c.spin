{
    --------------------------------------------
    Filename: sensor.baro.mpl3115a2.i2c.spin
    Author: Jesse Burt
    Description: Driver for MPL3115A2 Pressure
        sensor with altimetry
    Copyright (c) 2021
    Started Feb 01, 2021
    Updated Feb 01, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

' Operating modes
    SINGLE          = 0
    CONT            = 1

' Temperature scales
    C               = 0
    F               = 1

VAR

    long _temp_scale

OBJ

' choose an I2C engine below
    i2c : "com.i2c"                             ' PASM I2C engine (up to ~800kHz)
    core: "core.con.mpl3115a2.spin"             ' hw-specific low-level const's
    time: "time"                                ' basic timing functions

PUB Null{}
' This is not a top-level object

PUB Start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ): status
' Start using custom IO pins and I2C bus frequency
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate pins and bus freq
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            if i2c.present(SLAVE_WR)            ' test device bus presence
                if deviceid{} == core#DEVID_RESP' validate device 
                    return
    ' if this point is reached, something above failed
    ' Re-check I/O pin assignments, bus speed, connections, power
    ' Lastly - make sure you have at least one free core/cog 
    return FALSE

PUB Stop{}

    i2c.deinit{}

PUB Defaults{}
' Set factory defaults
    reset{}

PUB Preset_Active{}
' Like Defaults(), but
'   * continuous sensor measurement
    reset{}
    opmode(CONT)

PUB DeviceID{}: id
' Read device identification
'   Returns: $C4
    readreg(core#WHO_AM_I, 1, @id)

PUB OpMode(mode): curr_mode
' Set operating mode
'   Valid values:
'       SINGLE (0): Single-shot/standby
'       CONT (1): Continuous measurement
    curr_mode := 0
    readreg(core#CTRL_REG1, 1, @curr_mode)
    case mode
        SINGLE, CONT:
            writereg(core#CTRL_REG1, 1, @mode)
        other:
            return (curr_mode & 1)

PUB PressData{}: press_adc
' Read pressure data
'   Returns: s20 (Q18.2 fixed-point)
    readreg(core#OUT_P_MSB, 3, @press_adc)

PUB PressPascals{}: press | p_frac
' Read pressure data, in Pascals
    press := pressdata >> 4
    p_frac := press & %11
    return ((press >> 2) * 10) + p_frac         ' ((p / 4) * 10) + (p // 4)

PUB Reset{} | tmp
' Reset the device
    tmp := (1 << core#RST)
    writereg(core#CTRL_REG1, 1, @tmp)
    time.usleep(core#T_POR)

PUB TempData{}: temp_adc
' Read temperature data
'   Returns: s12 (Q8.4 fixed-point)
    readreg(core#OUT_T_MSB, 2, @temp_adc)

PUB Temperature{}: temp
' Current temperature, in hundredths of a degree
'   Returns: Integer
'   (e.g., 2105 is equivalent to 21.05 deg C)
    temp := calctemp(tempdata{})
    case _temp_scale
        C:
        F:
            return ((temp * 9_00) / 5_00) + 32_00

PUB TempScale(scale): curr_scale
' Set temperature scale used by Temperature method
'   Valid values:
'      *C (0): Celsius
'       F (1): Fahrenheit
'   Any other value returns the current setting
    case scale
        C, F:
            _temp_scale := scale
        other:
            return _temp_scale

PRI calcTemp(temp_word): temp_c | whole, part
' Calculate temperature in degrees Celsius, given ADC word
    temp_word := (temp_word << 16) ~> 20        ' extend sign bit
    whole := (temp_word >> 4) * 100             ' scale up to hundredths
    part := (temp_word & %1111)                 ' fractional part
    return whole+part

PRI readReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Read nr_bytes from the device into ptr_buff
    case reg_nr                                 ' validate register num
        $00..$FF:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)
            i2c.start{}
            i2c.wr_byte(SLAVE_RD)

    ' write MSByte to LSByte
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}
        other:                                  ' invalid reg_nr
            return

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt
' Write nr_bytes to the device from ptr_buff
    case reg_nr
        $00..$FF:
            cmd_pkt.byte[0] := SLAVE_WR
            cmd_pkt.byte[1] := reg_nr
            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 2)

    ' write MSByte to LSByte
            i2c.wrblock_msbf(ptr_buff, nr_bytes)
            i2c.stop{}
        other:
            return


DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
