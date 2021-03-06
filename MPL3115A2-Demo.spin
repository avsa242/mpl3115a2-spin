{
    --------------------------------------------
    Filename: MPL3115A2-Demo.spin
    Author: Jesse Burt
    Description: Demo of the MPL3115A2 driver
    Copyright (c) 2021
    Started Feb 01, 2021
    Updated Feb 01, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-defined constants
    SER_BAUD    = 115_200
    LED         = cfg#LED1

    I2C_SCL     = 28
    I2C_SDA     = 29
    I2C_HZ      = 400_000

    MODE        = BAR                           ' ALT(itude) or BAR(ometer)
' --

    BAR         = 0
    ALT         = 1
    C           = 0
    F           = 1

    DAT_X_COL   = 25

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    time    : "time"
    int     : "string.integer"
    baro    : "sensor.baro.mpl3115a2.i2c"

PUB Main{}

    setup{}
    baro.preset_active{}                        ' set defaults, but enable
                                                ' sensor power

    baro.altbaromode(MODE)

    baro.tempscale(C)                           ' C, F
    baro.sealevelpress(100_100)                 ' your sea level pressure (Pa)

    case MODE
        BAR:
            repeat
                ser.position(0, 3)
                presscalc{}
                tempcalc{}
        ALT:
            repeat
                ser.position(0, 3)
                altcalc{}
                tempcalc{}

PUB AltCalc{} | a, fa, altf

    ser.str(string("Altitude (m):"))
    ser.positionx(DAT_X_COL)
    decimal(baro.altitude{}, 100)
    ser.clearline{}
    ser.newline{}

PUB PressCalc{}

    ser.str(string("Barometric pressure (Pa):"))
    ser.positionx(DAT_X_COL)
    decimal(baro.presspascals{}, 10)
    ser.clearline{}
    ser.newline{}

PUB TempCalc{}

    ser.str(string("Temperature: "))
    ser.positionx(DAT_X_COL)
    decimal(baro.temperature, 100)
    ser.clearline{}
    ser.newline{}

PRI Decimal(scaled, divisor) | whole[4], part[4], places, tmp, sign
' Display a scaled up number as a decimal
'   Scale it back down by divisor (e.g., 10, 100, 1000, etc)
    whole := scaled / divisor
    tmp := divisor
    places := 0
    part := 0
    sign := 0
    if scaled < 0
        sign := "-"
    else
        sign := " "

    repeat
        tmp /= 10
        places++
    until tmp == 1
    scaled //= divisor
    part := int.deczeroed(||(scaled), places)

    ser.char(sign)
    ser.dec(||(whole))
    ser.char(".")
    ser.str(part)
    ser.chars(" ", 5)

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if baro.startx(I2C_SCL, I2C_SDA, I2C_HZ)
        ser.strln(string("MPL3115A2 driver started"))
    else
        ser.strln(string("MPL3115A2 driver failed to start - halting"))
        repeat

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
