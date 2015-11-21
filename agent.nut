// Copyright (c) 2015 Electric Imp
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class Plotly {

    static version = [1, 0, 0];

    static function getPlotlyTimestamp(providedTimestamp = null) {
        local timestamp = providedTimestamp == null ? date() : date(providedTimestamp);
        return format("%04i-%02i-%02i %02i:%02i:%02i",
            timestamp.year, timestamp.month, timestamp.day,
            timestamp.hour, timestamp.min, timestamp.sec);
    }

    static PLOTLY_ENDPOINT = "https://plot.ly/clientresp";
    static PLOTLY_PLATFORM = "electricimp"

    static MESSAGETYPE_PLOT = "plot";
    static MESSAGETYPE_STYLE = "style";
    static MESSAGETYPE_LAYOUT = "layout";

    _url = null;
    _username = null;
    _userKey = null;
    _filename = null;
    _worldReadable = null;
    _persistentLayout = null;
    _persistentStyle = null;

    function constructor(username, userKey, filename, worldReadable, traces, callback = null) {
        _url = "";
        _username = username;
        _userKey = userKey;
        _filename = filename;
        _worldReadable = worldReadable;
        _persistentLayout = {"xaxis" : {}, "yaxis" : {}};
        _persistentStyle = [];
        local plotlyInput = [];

        // Setup blank traces to be appended to later
        foreach(trace in traces) {
            plotlyInput.append({
                "x" : [],
                "y" : [],
                "name" : trace,
                "connectgaps" : false,
            });
            _persistentStyle.append({
                "name" : trace
            });
        }

        _makeApiCall(MESSAGETYPE_PLOT, plotlyInput, callback);
    }

    function getUrl() {
        return _url;
    }

    function post(dataObjs, callback = null) {;
        _makeApiCall(MESSAGETYPE_PLOT, dataObjs, callback);
    }

    function setTitle(title, callback = null) {
        _persistentLayout["title"] <- title;
        _makeApiCall(MESSAGETYPE_LAYOUT, _persistentLayout, callback);
    }

    function setAxisTitles(xAxisTitle, yAxisTitle, callback = null) {
        if(xAxisTitle != null && xAxisTitle.len() > 0) {
            _persistentLayout["xaxis"]["title"] <- xAxisTitle;
        }
        if(yAxisTitle != null && yAxisTitle.len() > 0) {
            _persistentLayout["yaxis"]["title"] <- yAxisTitle;
        }
        _makeApiCall(MESSAGETYPE_LAYOUT, _persistentLayout, callback);
    }

    function addSecondYAxis(axisTitle, traces, callback = null) {
            _persistentLayout["yaxis2"] <- {
                "title" : axisTitle,
                "side" : "right",
                "overlaying" : "y"
            };
            // Search for requested traces in style table
            foreach(trace in _persistentStyle) {
                if(traces.find(trace["name"]) != null) {
                    trace["yaxis"] <- "y2";
                }
            }
            local secondAxisCallback = _getSecondAxisLayoutCallback(callback).bindenv(this);
            _makeApiCall(MESSAGETYPE_LAYOUT, _persistentLayout, secondAxisCallback);
    }

    function setStyleDirectly(styleTable, callback = null) {
        // Note that this overwrites the existing style table
        _persistentStyle = styleTable;
        _makeApiCall(MESSAGETYPE_STYLE, _persistentStyle, callback);
    }

    function setLayoutDirectly(layoutTable, callback = null) {
        // Note that this overwrites the existing layout table
        _persistentLayout = layoutTable;
        _makeApiCall(MESSAGETYPE_LAYOUT, _persistentLayout, callback);
    }


    /******************** PRIVATE FUNCTIONS (DO NOT CALL) ********************/
    function _getSecondAxisStyleCallback(err1, response1, parsed1, userCallback) {
        return function(err2, response2, parsed2) {
            if(userCallback != null) {
                // Since adding a second y-axis requires two API calls, pass the "worse" response into the user callback
                local returnedResponse = response1.statuscode > response2.statuscode ? response1 : response2;
                local returnedErr = response1.statuscode > response2.statuscode ? err1 : err2;
                local returnedParsed = response1.statuscode > response2.statuscode ? parsed1 : parsed2;
                imp.wakeup(0, function() {
                    userCallback(returnedErr, returnedResponse, returnedParsed);
                });
            }
        }
    }

    function _getSecondAxisLayoutCallback(userCallback) {
        return function(err1, response1, parsed1) {
            local callback =  _getSecondAxisStyleCallback(err1, response1, parsed1, userCallback);
            setStyleDirectly(_persistentStyle, callback);
        }
    }

    function _getApiRequestCallback(userCallback) {
        return function(response){
            local error = null;
            local responseTable = null;
            if(response.statuscode == 200) {
                try{
                    responseTable = http.jsondecode(response.body);
                    if("url" in responseTable && responseTable.url.len() > 0) {
                        _url = responseTable.url;
                    }
                    if("error" in responseTable && responseTable.error.len() > 0) {
                        error = responseTable.error;
                    }
                } catch(exception) {
                    error = "Could not decode Plotly response";
                }
            } else {
                error = "HTTP Response Code " + response.statuscode;
            }
            if(userCallback != null) {
                imp.wakeup(0, function() {
                    userCallback(error, response, responseTable);
                });
            }
        }
    }

    function _makeApiCall(type, requestArgs, userCallback) {
        local requestKwargs = {
            "filename" : _filename,
            "fileopt" : "extend",
            "world_readable" : _worldReadable
        };

        local requestData = {
            "un" : _username,
            "key" : _userKey,
            "origin" : type,
            "platform" : PLOTLY_PLATFORM,
            "version" : format("%i.%i.%i", version[0], version[1], version[2]),
            "args" : http.jsonencode(requestArgs),
            "kwargs" : http.jsonencode(requestKwargs)
        };

        local requestString = http.urlencode(requestData);
        local request = http.post(PLOTLY_ENDPOINT, {}, requestString);

        local apiRequestCallback = _getApiRequestCallback(userCallback);
        request.sendasync(apiRequestCallback.bindenv(this));
    }
}

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
            x = time_stamp,
            y = y_val,
            name = location,
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
        
        local style =
            [
                {
                    "name" : "Ambient",
                    "yaxis" : "y"
                },
                {
                    "name" : "Lower Growbed",
                    "yaxis" : "y"
                },
                {
                    "name" : "Growbed Nutrient Tank",
                    "yaxis" : "y"
                },
                {
                    "name" : "Upper Growbed",
                    "yaxis" : "y"
                },
                {
                    "name" : "Lower NFT Nutrient Tank",
                    "yaxis" : "y"
                },
                {
                    "name" : "supplyvoltage",
                    "yaxis" : "y"
                },
                {
                    "name" : "lightlevel",
                    "yaxis" : "y2"
                },
                {
                    "name" : "lux",
                    "yaxis" : "y4"
                },
                {
                    "name" : "ambientbmp",
                    "yaxis" : "y"
                },
                {
                    "name" : "millibars",
                    "yaxis" : "y3"
                }
            ];
        plot1.setStyleDirectly(style, function(error, response, decoded) {
            if(error != null) {
                server.log(error);
                return;
                }
            

            server.log("See plot at " + plot1.getUrl());
        });
    });
}

local traces = ["Ambient", "Lower Growbed", "Growbed Nutrient Tank", "Upper Growbed", "Lower NFT Nutrient Tank", "supplyvoltage", "lightlevel", "millibars", "ambientbmp", "lux"];
plot1 <- Plotly("your_plotly_username", "your_plotly_api_key", "Hydroponic Greenhouse Temperatures", true, traces, constructorCallback);



