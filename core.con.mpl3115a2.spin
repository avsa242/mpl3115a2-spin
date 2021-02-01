{
    --------------------------------------------
    Filename: core.con.mpl3115a2.spin
    Author:
    Description:
    Copyright (c) 2021
    Started Feb 01, 2021
    Updated Feb 01, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' I2C Configuration
    I2C_MAX_FREQ    = 400_000                   ' device max I2C bus freq
    SLAVE_ADDR      = $60 << 1                  ' 7-bit format slave address
    T_POR           = 1_000_000                 ' startup time (usecs)
    ' NOTE: 1sec startup time (high-res mode), 60ms (high-speed mode)
    DEVID_RESP      = $C4                       ' device ID expected response

' Register definitions

    WHO_AM_I        = $0C

PUB Null{}
' This is not a top-level object

