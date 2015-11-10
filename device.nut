
/* Basic code to read temperature from BMP085 & TMP102 device via I2C */
// BMP085 and TMP102 Temperature Reader

//-----------------------------------------------------------------------------------------
class TempDevice_BMP085 {
    // Data Members
    //   i2c parameters
    i2cPort = null;
    i2cAddress = null;
    oversampling_setting = 2; // 0=lowest precision/least power, 3=highest precision/most power
    //   calibration coefficients
    ac1 = 0;
	ac2 = 0;
	ac3 = 0;
	ac4 = 0;
	ac5 = 0;
	ac6 = 0;
	b1 = 0;
	b2 = 0;
	mb = 0;
	mc = 0;
	md = 0;
    
    //-------------------
    constructor( i2c_port, i2c_address7bit ) {
        // example:   local mysensor = TempDevice_BMP085(I2C_89, 0x49);
        if(i2c_port == I2C_12)
        {
            // Configure I2C bus on pins 1 & 2
            hardware.configure(I2C_12);
            hardware.i2c12.configure(CLOCK_SPEED_100_KHZ);
            i2cPort = hardware.i2c12;
        }
        else if(i2c_port == I2C_89)
        {
            // Configure I2C bus on pins 8 & 9
            hardware.configure(I2C_89);
            hardware.i2c89.configure(CLOCK_SPEED_100_KHZ);
            i2cPort = hardware.i2c89;
        }
        else
        {
            server.log("Invalid I2C port " + i2c_port + " specified in TempDevice_BMP085::constructor.");
        }

        // To communicate with the device, the datasheet wants the 7 bit address + 1 bit for direction,
        // which can be left at 0 since one of the forums says the I2C always sets the last bit to the 
        // appropriate value 1/0 for read/write. We accout for the 1 bit by bitshifting <<1.
        // So, specify i2c_address7bit=0x49, and the code will use: i2cAddress= 1001001 0 = 0b1001.0010 = 0x92
        i2cAddress = (i2c_address7bit << 1);
        
        read_calibration_data();
    }

    function read_uint_register( register_address ) {
        // read two bytes from i2c device and converts it to a short  (2 byte) unsigned int.
        // register_address is MSB in format "\xAA"
    
        //local reg_dataMSB = i2cPort.read(i2cAddress, "\xB0", 1);
        //local reg_dataLSB = i2cPort.read(i2cAddress, "\xB1", 1);
        //server.log( "MSB(B0)=" + (reg_dataMSB[0] & 0xFF) + " LSB(B1)=" + (reg_dataLSB[0] & 0xFF) );
    
        // This command reads 2 bytes.  If register_address=0xAA then
        //         register 0xAA goes into reg_data[0]
        //         register 0xAB goes into reg_data[1]
        local reg_data = i2cPort.read(i2cAddress, register_address, 2);
        local output_int = ((reg_data[0] & 0xFF) << 8) | (reg_data[1] & 0xFF);
        // data sheet says that 0x0 and 0xffff denote bad reads. Can check integrity for looking for these values.
        if (output_int == null || output_int==0x0 || output_int == 0xffff){
            server.log( "ERROR: bad I2C return value" + reg_data + " from address " + register_address );
        }
        
        //server.log( "reg_data[0]=" + reg_data[0] + " reg_data[1]=" + reg_data[1] );
        return output_int;
    }

    function read_int_register( register_address ) {
        // read two bytes from i2c device and converts it to a short (2 byte) signed int.
        // register_address is MSB in format "\xAA"
        local reg_data = i2cPort.read(i2cAddress, register_address, 2);
        local output_int = ((reg_data[0] & 0xFF) << 8) | (reg_data[1] & 0xFF);
        // Is negative value? Convert from 2's complement:
        if (reg_data[0] & 0x80) {
            output_int = (0xffff ^ output_int) + 1;
            output_int *= -1;
        }
        // data sheet says that 0x0 and 0xffff denote bad reads. Can check integrity for looking for these values.
        if (output_int == null || output_int==0x0 || output_int == 0xffff){
            server.log( "ERROR: bad I2C return value" + reg_data + " from address " + register_address );
            //server.sleepfor(2); // puts the Imp into DEEP SLEEP, powering it down for 5 seconds. when it wakes, it re-downloads its firmware and starts over.
        }
        return output_int;
    }

    //-------------------
    function read_calibration_data() {
        // The BMP085 has 11 words of calibration data that the factor stores on
        //    the device's EEprom. Each device has different coefficients that need to be
        //    read at power up.
        // all values are signed SHORT, except where noted
        ac1 = read_int_register("\xAA");
        ac2 = read_int_register("\xAC");
	    ac3 = read_int_register("\xAE");
	    ac4 = read_uint_register("\xB0"); // needs to be unsigned short
	    ac5 = read_uint_register("\xB2"); // needs to be unsigned short
	    ac6 = read_uint_register("\xB4"); // needs to be unsigned short
	    b1  = read_int_register("\xB6");
	    b2  = read_int_register("\xB8");
	    mb  = read_int_register("\xBA");
	    mc  = read_int_register("\xBC");
	    md  = read_int_register("\xBE");
        
        /*
        server.log( "Finished cal reading ac1=" + ac1 + " and ac2=" + ac2 );
        server.log( "Finished cal reading ac3=" + ac3 + " and ac4=" + ac4 );
        server.log( "Finished cal reading ac5=" + ac5 + " and ac6=" + ac6 );
        server.log( "Finished cal reading b1=" + b1 + " and b2=" + b2 );
        server.log( "Finished cal reading mb=" + mb + " and mc=" + mc + " and md=" + md );
        */
    }   
    
    //-------------------
    function read_temp_Celsius() {
        
        // to write to our i2c device this we need to mask the last bit into a 1.
        i2cPort.write(i2cAddress | 0x01, "\xF4\x2E" ); // write 0x2E into register 0xF4
        // Wait for conversion to finish. datasheet wants 4.5ms, we double it:
        imp.sleep(0.01);
     
        // Read msb and lsb
        local ut = read_int_register("\xF6");
        //server.log( "Reading UT=" + ut );
        
        // Calculate calibrated temperature:
        // Code is derived from http://forums.electricimp.com/discussion/736/bmp085-sensor-i2c#Item_5        
        //   or datasheet page 13
	    local x1 = (ut - ac6) * ac5 >> 15;
	    local x2 = (mc << 11) / (x1 + md);        
        local temp = ((x1 + x2 + 8) >> 4)*0.1;
        return temp;
    }

    //-------------------
    function read_pressure_kilopascal() {
        // Returns the atmospheric pressure in kilopascals.
        // note!: the datasheet suggests the device uses the previous temperature reading for this,
        //    so do a read_temp_Celsius() before a pressure reading.
            
        // ----  Do TEMPERATURE conversion ----
        // to do this we need to mask the last bit into a 1.
        i2cPort.write(i2cAddress | 0x01, "\xF4\x2E" ); // write 0x2E into register 0xF4
        // Wait for conversion to finish. datasheet wants 4.5ms, we double it:
        imp.sleep(0.01);
        local ut = read_int_register("\xF6");
        // Calculate calibrated temperature:
        local x1 = (ut - ac6) * ac5 >> 15;
	    local x2 = (mc << 11) / (x1 + md);        
        local b5 = x1 + x2;
    	//local temperature = ((b5 + 8) >> 4)*0.1;

    	//calculate true pressure
	    local b6 = b5 - 4000;
	    x1 = (b2 * (b6 * b6 >> 12)) >> 11; 
	    x2 = (ac2 * b6) >> 11;
	    local x3 = x1 + x2;
	    local b3 = (((ac1 * 4 + x3)<<oversampling_setting) + 2) >> 2;
	    x1 = ac3 * b6 >> 13;
	    x2 = (b1 * (b6 * b6 >> 12)) >> 16;
	    x3 = ((x1 + x2) + 2) >> 2;
		local b4 = (ac4 * (x3 + 32768)) >> 15;

        // to write to our i2c device this we need to mask the last bit into a 1.
        // write 0x34+(oversampling_setting<<6) into register 0xF4
        i2cPort.write(i2cAddress | 0x01, format("%c%c", 0xF4, 0x34+(oversampling_setting<<6) ) ); 
        // Wait for conversion to finish. datasheet wants 4.5ms, we double it:
        imp.sleep(0.01*oversampling_setting+0.01);
        local reg_data = i2cPort.read(i2cAddress, "\xF6", 3);
        local up = ( ((reg_data[0] & 0xFF) << 16) | ((reg_data[1] & 0xFF) << 8) | (reg_data[2]&0xFF) )
                    >> (8-oversampling_setting);
	    local b7 = (up - b3) * (50000 >> oversampling_setting);
	    local p = b7 < 0x80000000 ? (b7 * 2) / b4 : (b7 / b4) * 2;
	    x1 = (p >> 8) * (p >> 8);
	    x1 = (x1 * 3038) >> 16;
	    x2 = (-7357 * p) >> 16;
        
	    local pressure = p + ((x1 + x2 + 3791) >> 4);  // pascals
        return pressure / 1000.;  // kilopascals
    }
    
    //-------------------
    function read_pressure_atm() {
        // 1 atm = 101.325 kilopascal
        return read_pressure_kilopascal() /101.325;
    }
}
   
//---------------------------------------------------------------
local mysensorBMP = TempDevice_BMP085(I2C_89, 0x77);

/* Basic code to read light level from a BH1750 device via I2C */
// This code is based loosely on the BMP085 and TMP102 Temperature Reader
// because I already had those sensors working and it seemed like a good 
// place to start.

//-----------------------------------------------------------------------------------------
class LightDevice_BH1750 {
    // Data Members
    //   i2c parameters
    i2cPort = null;
    i2cAddress = null;
    oversampling_setting = 2; // 0=lowest precision/least power, 3=highest precision/most power

    
    //-------------------
    constructor( i2c_port, i2c_address ) {
        // example:   local mysensor = TempDevice_BMP085(I2C_89, 0x49);
        if(i2c_port == I2C_12)
        {
            // Configure I2C bus on pins 1 & 2
            hardware.configure(I2C_12);
            hardware.i2c12.configure(CLOCK_SPEED_100_KHZ);
            i2cPort = hardware.i2c12;
        }
        else if(i2c_port == I2C_89)
        {
            // Configure I2C bus on pins 8 & 9
            hardware.configure(I2C_89);
            hardware.i2c89.configure(CLOCK_SPEED_100_KHZ);
            i2cPort = hardware.i2c89;
        }
        else
        {
            server.log("Invalid I2C port " + i2c_port + " specified in TempDevice_BMP085::constructor.");
        }

        i2cAddress = i2c_address;
        
    }


    function read_int_register( register_address ) {
        // read two bytes from i2c device and converts it to a short (2 byte) signed int.
        // register_address is MSB in format "\xAA"
        local reg_data = i2cPort.read(i2cAddress, register_address, 2);
        //server.log(reg_data);
        local output_int = ((reg_data[0] & 0xFF) << 8) | (reg_data[1] & 0xFF);
        // Is negative value? Convert from 2's complement:
        if (reg_data[0] & 0x80) {
            output_int = (0xffff ^ output_int) + 1;
            output_int *= -1;
        }
        // data sheet says that 0x0 and 0xffff denote bad reads. Can check integrity for looking for these values.
        if (output_int == null || output_int==0x0 || output_int == 0xffff){
            server.log( "ERROR: bad I2C return value" + reg_data + " from address " + register_address );
            //server.sleepfor(2); // puts the Imp into DEEP SLEEP, powering it down for 5 seconds. when it wakes, it re-downloads its firmware and starts over.
        }
        return output_int;
    }

    //-------------------
    function read_light_level() {
        
        // to write to our i2c device this we need to mask the last bit into a 1.
        // We can use a variety of different commands to begin conversion.
        // 0x10 is High res, continuous mode (1lux resolution)
        // 0x11 is High res, continuous mode 2 (0.5 lux resolution)
        // 0x20 is High res, one-time mode (1 lux res)
        // 0x21 is High res, one-time mode 2 (0.5 lux res)
        i2cPort.write(i2cAddress | 0x01, "\x10" ); // write 0x10 into register 0xF4
        // Wait for conversion to finish. datasheet wants 180ms max
        imp.sleep(0.18);
     
        // Read msb and lsb 
        local light_level = read_int_register("\x02");
        //server.log( "Reading Light Level=" + light_level );
        
        return light_level;
    }


}

//---------------------------------------------------------------
local mysensor = LightDevice_BH1750(I2C_89, 0xb8);
local counter = 0;


function one_wire_reset()
{
    // Configure UART for 1-Wire RESET timing
    
    ow.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS);
    ow.write(0xF0);
    ow.flush();
    if (ow.read() == 0xF0)
    {
        // UART RX will read TX if there's no device connected
        
        server.log("No 1-Wire devices are present.");
        return false;
    } 
    else 
    {
        // Switch UART to 1-Wire data speed timing
        
        ow.configure(115200, 8, PARITY_NONE, 1, NO_CTSRTS);
        return true;
    }
}


function one_wire_write_byte(byte)
{
    for (local i = 0; i < 8; i++, byte = byte >> 1)
    {
        // Run through the bits in the byte, extracting the
        // LSB (bit 0) and sending it to the bus
        
        one_wire_bit(byte & 0x01);
    }
} 


function one_wire_read_byte()
{
    local byte = 0;
    for (local i = 0; i < 8; i++)
    {
        // Build up byte bit by bit, LSB first
        
        byte = (byte >> 1) + 0x80 * one_wire_bit(1);
    }
    
    return byte;
}


function one_wire_bit(bit)
{
    bit = bit ? 0xFF : 0x00;
    ow.write(bit);
    ow.flush();
    local return_value = ow.read() == 0xFF ? 1 : 0;
    return return_value;
} 


function one_wire_search(next_node)
{
    local last_fork_point = 0;

    // Reset the bus and exit if no device found

    if (one_wire_reset())
    {
        // There are 1-Wire device(s) on the bus, so issue the 1-Wire SEARCH command (0xF0)
        
        one_wire_write_byte(0xF0);
     
        // Work along the 64-bit ROM code, bit by bit, from LSB to MSB
        
        for (local i = 64 ; i > 0 ; i--) 
        {
            local byte = (i - 1) / 8;
            
            // Read bit from bus
            
            local bit = one_wire_bit(1);
            
            // Read the next bit
            
            if (one_wire_bit(1))
            {
                if (bit) 
                {
                    // Both bits are 1 which indicates that there are no further devices
                    // on the bus, so put pointer back to the start and break out of the loop
                    
                    last_fork_point = 0;
                    break;
                }
            } 
            else if (!bit) 
            {
                // First and second bits are both 0: we're at a node
                
                if (next_node > i || (next_node != i && (id[byte] & 1)))
                {
                    // Take the '1' direction on this point
                    
                    bit = 1;
                    last_fork_point = i;
                }                
            }

            // Write the 'direction' bit. For example, if it's 1 then all further
            // devices with a 0 at the current ID bit location will go offline
            
            one_wire_bit(bit);
            
            // Write the bit to the current ID record

            id[byte] = (id[byte] >> 1) + 0x80 * bit;
        }
    }

    // Return the last fork point so it can form the start of the next search
    
    return last_fork_point;
}


function one_wire_slaves()
{
    id <- [0,0,0,0,0,0,0,0];
    next_device <- 65;
    //server.log("one_wire_slaves");

    while(next_device)
    {
        next_device = one_wire_search(next_device);
        
        // Store the device ID discovered by one_wire_search() in an array
        // Nb. We need to clone the array, id, so that we correctly save 
        // each one rather than the address of a single array
        
        slaves.push(clone(id));
    }
}



function get_temp()
{
    //server.log("getting temps...");
    local temp_LSB = 0; 
    local temp_MSB = 0; 
    local temp_celsius = 0; 

    // We are not doing this imp.wakeup because we're using deep sleep instead with server.sleepfor called by imp.onidle
    //imp.wakeup(5.0, get_temp);
    
    // Reset the 1-Wire bus
    
    one_wire_reset();
    
    // Issue 1-Wire Skip ROM command (0xCC) to select all devices on the bus
    
    one_wire_write_byte(0xCC);
    
    // Issue DS18B20 Convert command (0x44) to tell all DS18B20s to get the temperature
    // Even if other devices don't ignore this, we will not read them
    
    one_wire_write_byte(0x44);
    
    // Wait 750ms for the temperature conversion to finish
    
    imp.sleep(0.75);

    local bigdata=[]
    foreach (device, slave_id in slaves)
    {
        // Run through the list of discovered slave devices, getting the temperature
        // if a given device is of the correct family number: 0x28 for BS18B20
        
        if (slave_id[7] == 0x28)
        {
            one_wire_reset();
            
            // Issue 1-Wire MATCH ROM command (0x55) to select device by ID
            
            one_wire_write_byte(0x55);
            
            // Write out the 64-bit ID from the array's eight bytes
            
            for (local i = 7 ; i >= 0; i--)
            {
                one_wire_write_byte(slave_id[i]);
            }
            
            // Issue the DS18B20's READ SCRATCHPAD command (0xBE) to get temperature
            
            one_wire_write_byte(0xBE);
            
            // Read the temperature value from the sensor's RAM
            
            temp_LSB = one_wire_read_byte();
            temp_MSB = one_wire_read_byte();
            
            // Signal that we don't need any more data by resetting the bus
            
            one_wire_reset();

            // Calculate the temperature from LSB and MSB
            
            temp_celsius = ((temp_MSB * 256) + temp_LSB) / 16.0;
 
            server.log(format("Device: %02d Family: %02x Serial: %02x%02x%02x%02x%02x%02x Temp: %3.2f", (device + 1), slave_id[7], slave_id[1], slave_id[2], slave_id[3], slave_id[4], slave_id[5], slave_id[6], temp_celsius));
            local sensordata = {
                device_num = (device + 1),
                family = slave_id[7],
                serial = format("%02x%02x%02x%02x%02x%02x", slave_id[1], slave_id[2], slave_id[3], slave_id[4], slave_id[5], slave_id[6]),
                reading = temp_celsius,
                reading_type = "celcius",
                //time_stamp = getTime()
            }
            bigdata.append(sensordata);
        }
    }
    bigdata.append({
    device_num = "6",
    family = "ElectricImp",
    serial = "supplyvoltage",
    reading = hardware.voltage(),
    reading_type = "voltage",
    //time_stamp = getTime()    
    })
    server.log(format("Supply Voltage: %2.3f", hardware.voltage()));
    bigdata.append({
    device_num = "7",
    family = "ElectricImp",
    serial = "lightlevel",
    reading = hardware.lightlevel()/10000.0,
    reading_type = "lightlevel",
    //time_stamp = getTime()    
    })
    server.log(format("Light Level: %2.3f", hardware.lightlevel()/10000.0));
    return bigdata;
    
}

// PROGRAM STARTS HERE

// Set our idle function to sleep until one minute from now.
imp.onidle(function() {
    //server.log("Time for a nap.");
    //server.sleepfor(60);
    // every minute, on the minute
    server.sleepfor(60 - (time() % 60));
});


ow <- hardware.uart57;
slaves <- [];

// Enumerate the slaves on the bus

one_wire_slaves();

// Start sampling temperature data
local bigdata=get_temp();
local lux = mysensor.read_light_level()/1.2;
server.log( "BH1750: " + lux + " lux " );
    bigdata.append({
    device_num = "8",
    family = "ElectricImp",
    serial = "lux",
    reading = lux,
    reading_type = "lux",
    //time_stamp = getTime()    
    })
local temp2 = mysensorBMP.read_temp_Celsius();
    bigdata.append({
    device_num = "9",
    family = "ElectricImp",
    serial = "ambientbmp",
    reading = temp2,
    reading_type = "celcius",
    //time_stamp = getTime()    
    })
local pressure = mysensorBMP.read_pressure_atm();
    bigdata.append({
    device_num = "10",
    family = "ElectricImp",
    serial = "millibars",
    reading = pressure*1013.25,
    reading_type = "millibars",
    //time_stamp = getTime()    
    })
agent.send("bigdata", bigdata);
server.log( "BMP180: " + temp2 + " C, " + pressure + " atm., " + pressure*1013.25 + " millibars" );
