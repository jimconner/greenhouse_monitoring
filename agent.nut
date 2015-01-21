device.on("bigdata" function(msg) {
    local data = [];
    foreach (reading in msg)
    {
        //server.log(reading.temp);
        local location="";
        if ( reading.serial=="000006564987" )
            location = "Ambient";
        else if ( reading.serial == "00000575b513" )
            location = "Lower Growbed";
        else if ( reading.serial == "00000575aa83" )
            location = "Growbed Nutrient Tank";
        else if ( reading.serial == "00000655770d" )
            location="Upper Growbed";
        else if ( reading.serial == "000006562fd1" )
            location="Lower NFT Nutrient Tank";
        else 
        location=reading.serial;
        local yaxis_value="y";
        if ( location == "Supply Voltage" )
            yaxis_value="y2";
        
        data.append({
            x = reading.time_stamp,
            y = reading.temp,
            name = location,
            yaxis = yaxis_value,
        });
    }
    

    // Plotly Layout Object
    local layout = {
        fileopt = "extend",
        //filename = location,
        filename = "Hydroponic Greenhouse Temperatures",
        layout={
            title="Hydroponic Greenhouse Temperatures"
            yaxis={
                title="Temperature (°C)",
                side="left",
            }
            yaxis2={
                title="Voltage (V)",
                side="right",
                overlaying="y",
                range=["2.5","3.5"]
            }
        }
    };

    // Setting up Data to be POSTed
    local payload = {
    un = "Fecn",
    key = "7zfxbox7ac",
    origin = "plot",
    platform = "electricimp",
    args = http.jsonencode(data),
    kwargs = http.jsonencode(layout),
    version = "0.0.1"
    };

    // encode data and log
    local headers = { "Content-Type" : "application/json" };
    local body = http.urlencode(payload);
    local url = "https://plot.ly/clientresp";
    HttpPostWrapper(url, headers, body, true);
});    


// When Device sends new readings, Run this!
device.on("new_readings" function(msg) {

    //Plotly Data Object
    local data = [{
        x = msg.time_stamp, // Time Stamp from Device
        y = msg.temp // Sensor Reading from Device
        //yaxis = "y"+msg.device_num
    }];

    local location=""
    if ( msg.serial=="000006564987" )
        location = "Ambient";
    else if ( msg.serial == "00000575b513" )
        location = "Lower Growbed";
    else if ( msg.serial == "00000575aa83" )
        location = "Growbed Nutrient Tank";
    else if ( msg.serial == "00000655770d" )
        location="Upper Growbed";
    else if ( msg.serial == "000006562fd1" )
        location="Lower NFT Nutrient Tank";
    else 
        location=msg.serial;

    // Plotly Layout Object
    local layout = {
        fileopt = "extend",
        filename = location,
        //filename = "Mega Graph",
        layout={
            yaxis={
                title="Temperature",
                side="left",
            }
            //yaxis2={
            //    title="Voltage",
            //    side="right",
            //    overlaying="y",
            //}
        }
    };

    // Setting up Data to be POSTed
    local payload = {
    un = "Fecn",
    key = "7zfxbox7ac",
    origin = "plot",
    platform = "electricimp",
    args = http.jsonencode(data),
    kwargs = http.jsonencode(layout),
    version = "0.0.1"
    };

    // encode data and log
    local headers = { "Content-Type" : "application/json" };
    local body = http.urlencode(payload);
    local url = "https://plot.ly/clientresp";
    HttpPostWrapper(url, headers, body, true);
});


// Http Request Handler
function HttpPostWrapper (url, headers, string, log) {
  local request = http.post(url, headers, string);
  local response = request.sendsync();
  if (log)
    server.log(http.jsonencode(response));
  return response;
}

