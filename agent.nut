
#require "Plotly.class.nut:1.0.0"

function loggerCallback(error, response, decoded) {
    if(error == null) {
        server.log(response.body);
    } else {
        server.log(error);
    }
}

function postToPlotly(bigdata) {
    local time_stamp = plot1.getPlotlyTimestamp();
    local data = [];
    foreach (reading in bigdata)
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
    
    
    plot1.post(data, loggerCallback);
}

local constructorCallback = function(error, response, decoded) {

    if(error != null) {
        server.log(error);
        return;
    }

    device.on("bigdata", postToPlotly);


    // Plotly Layout Object
    local layout={
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
        };
    
    

    plot1.setLayoutDirectly(layout, function(error, response, decoded) {
        if(error != null) {
            server.log(error);
            return;
        }
        server.log(response);
        server.log(decoded);
        server.log("See plot at " + plot1.getUrl());
    });
}

local traces = ["Ambient", "Lower Growbed", "Growbed Nutrient Tank", "Upper Growbed", "Lower NFT Nutrient Tank", "supplyvoltage", "lightlevel", "millibars", "ambientbmp", "lux"];
plot1 <- Plotly("your_plotly_username", "your_plotly_api_key", "Hydroponic Greenhouse Temperatures", true, traces, constructorCallback);



