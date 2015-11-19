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
        if ( location == "Supply Voltage" || location == "Light Level")
            yaxis_value="y2";
        // Filter out invalid readings
        // Sometimes we read a value of 4096 degrees when there is 
        // interference on the bus. Let's discard anything over 99 degrees C
        local y_val = "";
        if ( reading.temp < 100 )
            y_val = reading.temp
        
        data.append({
            x = reading.time_stamp,
            y = y_val,
            name = location,
            yaxis = yaxis_value,
            connectgaps = false,
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
                range=["-5","35"]
            }
            yaxis2={
                title="Voltage (V)",
                side="right",
                overlaying="y",
                range=["0","6.6"]
            }
        }
    };

    // Setting up Data to be POSTed
    local payload = {
    un = "your_plotly_username",
    key = "your_plotly_api_key",
    origin = "plot",
    platform = "electricimp",
    args = http.jsonencode(data),
    kwargs = http.jsonencode(layout),
    version = "0.0.1"
    };

    // encode data and log
    local headers = { };
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
    key = "6t8opg7emt",
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
