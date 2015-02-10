// returns time string
// use 3600 and multiply by the hours +/- GMT.
// e.g for +5 GMT local date = date(time()+18000, "u");
function getTime() {
    local date = date(time(), "u");
    local sec = stringTime(date["sec"]);
    local min = stringTime(date["min"]);
    local hour = stringTime(date["hour"]);
    local day = stringTime(date["day"]);
    local month = date["month"]+1;
    local year = date["year"];
    return year+"-"+month+"-"+day+" "+hour+":"+min+":"+sec;
}

// function to fix time string
function stringTime(num) {
    if (num < 10)
        return "0"+num;
    else
        return ""+num;
}

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
                temp = temp_celsius,
                time_stamp = getTime()
            }
            bigdata.append(sensordata);
            //agent.send("new_readings", sensordata);
        }
    }
    bigdata.append({
    device_num = "6",
    family = "ElectricImp",
    serial = "Supply Voltage",
    temp = hardware.voltage(),
    time_stamp = getTime()    
    })
    server.log(format("Supply Voltage: %2.3f", hardware.voltage()));
    bigdata.append({
    device_num = "7",
    family = "ElectricImp",
    serial = "Light Level",
    temp = hardware.lightlevel()/10000.0,
    time_stamp = getTime()    
    })
    server.log(format("Light Level: %2.3f", hardware.lightlevel()/10000.0));
    agent.send("bigdata", bigdata);
 
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
get_temp();


