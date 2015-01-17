// When Device sends new readings, Run this!
device.on("new_readings" function(msg) {

    //Plotly Data Object
    local data = [{
        x = msg.time_stamp, // Time Stamp from Device
        y = msg.temp // Sensor Reading from Device
    }];

		// Change the device IDs and location names below to match your setup.
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
    };

    // Setting up Data to be POSTed
    local payload = {
    un = "your_username",
    key = "your_plotly_api_key",
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
