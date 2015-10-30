function logByLine(data, linebreak) {
    local lines = split(data, linebreak);
    foreach(line in lines) {
        server.log(line);
    }
}

// returns time string
// use 3600 and multiply by the hours +/- GMT.
// e.g for +5 GMT local date = date(time()+18000, "u");
function getTime() {
    local date = date(time(), "u");
    local sec = stringTime(date["sec"]);
    local min = stringTime(date["min"]);
    local hour = stringTime(date["hour"]);
    local day = stringTime(date["day"]);
    local month = stringTime(date["month"]+1);
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

device.on("bigdata" function(msg) {
    local data = [];
    local time_stamp = getTime();
    foreach (reading in msg)
    {
        //server.log(reading.temp);
        local location="";
        if ( reading.serial=="000006564987" )
            location = "Ambient";
        else if ( reading.serial == "00000575b513" )
            location = "Lower Growbed";
        else if ( reading.serial == "000006768ed0" )
            location = "Growbed Nutrient Tank";
        else if ( reading.serial == "00000655770d" )
            location="Upper Growbed";
        else if ( reading.serial == "00000677b6d9" )
            location="Lower NFT Nutrient Tank";
        else 
        location=reading.serial;
        local yaxis_value="y";
        if ( location == "supplyvoltage" || location == "lightlevel")
            yaxis_value="y2";
        if ( location == "millibars" )
            yaxis_value="y3";
        if ( location == "lux")
            yaxis_value="y4";
        
        // Filter out invalid readings
        // Sometimes we read a value of 4096 degrees when there is 
        // interference on the bus. Let's discard anything over 85 degrees C
        // as that is the max that a DS1820 can measure.
        local y_val = "";
        if ( reading.reading_type == "celcius" && reading.reading < 85 )
            y_val = reading.reading
            
        if ( reading.reading_type != "celcius")
            y_val = reading.reading
        
        data.append({
            //x = reading.time_stamp,
            x = time_stamp,
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
                range=["-2","35"]
            }
            yaxis2={
                title="Voltage (V)",
                side="left",
                position=0.05
                overlaying="y",
                range=["0","6.6"]
            }
            yaxis3={
                title="Pressure (Millibars)",
                side="right",
                overlaying="y",
                anchor="free",
                position=0.95
                range=["950","1050"]
            }
            yaxis4={
                title="Lux",
                side="right",
                overlaying="y",
                range=["0","1500"]
            }
        }
    };

    // Setting up Data to be POSTed
    local payload = {
    un = "your_plotly_username",
    key = "your_plotly_apikey",
    origin = "plot",
    platform = "electricimp",
    args = http.jsonencode(data),
    kwargs = http.jsonencode(layout),
    version = "0.0.2"
    };

    // encode data and log
    local headers = { "Content-Type" : "application/json" };
    local body = http.urlencode(payload);
    local url = "https://plot.ly/clientresp";
    HttpPostWrapper(url, headers, body, false);
    //logByLine(http.jsonencode(data), ",");
    
});    


// Http Request Handler
function HttpPostWrapper (url, headers, string, log) {
  local request = http.post(url, headers, string);
  local response = request.sendsync();
  if (log)
    server.log(http.jsonencode(response));
    logByLine(http.jsonencode(response), ",");
  return response;
}


