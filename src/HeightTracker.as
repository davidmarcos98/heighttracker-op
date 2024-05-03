[Setting category="Info" name="Enabled"]
bool enabled = false;

[Setting category="Info" name="Endpoint"]
string endpointUrl = "";

[Setting category="Info" name="mapUid"]
string mapUid = "";

[Setting category="Info" name="Interval (milliseconds)"]
int interval = 5000;


Net::HttpRequest@ PostAsync(const string &in url, const Json::Value &in data){
    auto req = Net::HttpRequest();
    req.Method = Net::HttpMethod::Post;
    req.Body = Json::Write(data);
    print(req.Body);
    req.Headers['Content-Type'] = 'application/json';
    req.Url = url;
    req.Start();
    
    while(!req.Finished()){
        sleep(10);
    }
    return req;
}

void Main(){
	auto app = cast<CTrackMania>(GetApp());
    string STATS_FILE = IO::FromDataFolder("PluginStorage/dips-plus-plus/stats.json");

    string currentMapUid = "";
    bool sendingMap = false;
    bool thisErrored = false;
    int retries = 5;
    int delay = interval;
    Json::Value payload = Json::Object();
    int saved = 0;

    while(true){
        auto map = app.RootMap;
    	auto TMData = PlayerState::GetRaceData();
        
        if(enabled && map !is null && map.MapInfo.MapUid != "" && app.Editor is null){
            auto mapUid = map.MapInfo.MapUid;
            if(currentMapUid != mapUid){
                print("Map changed. (old: "+tostring(currentMapUid)+" new: " + tostring(mapUid) +")");
                currentMapUid = mapUid;
                thisErrored = false;
                retries = 5;
                delay = interval;
            }
        } else if(enabled) {
            currentMapUid = "";
            thisErrored = false;
            retries = 5;
            delay = interval;
        }
        if(enabled && currentMapUid != "" && currentMapUid == mapUid && TMData.PlayerState == PlayerState::EPlayerState_Driving && !TMData.IsPaused && Math::Round(TMData.dPlayerInfo.Speed) > 0){
	        auto visState = VehicleState::ViewingPlayerState();
            if(sendingMap == false && (thisErrored == false || retries > 0)){
                sendingMap = true;
                Json::Value data = Json::Object();
                data["mapUid"] = currentMapUid;
                data["mapName"] = tostring(StripFormatCodes(map.MapInfo.Name));
                data["player"] = TMData.dPlayerInfo.Name;
                data["height"] = visState.Position.y;
                string time = tostring(Time::get_Stamp());
                payload[time] = data;
                saved = saved + 1;
                if(saved == 5){
                    print("Sending map info. ("+tostring(currentMapUid)+")");
                    if (IO::FileExists(STATS_FILE)) {
                        payload['dipsData'] = Json::FromFile(STATS_FILE);
                    }
                    auto result = PostAsync(endpointUrl, payload);
                    auto code = result.ResponseCode();
                    if(code == 200){
                        auto response = result.String();
                        if(response == currentMapUid){
                            print("Map info sent. (" + tostring(response) + ")");
                        }
                        payload = Json::Object();
                        saved = 0;
                    } else {
                        print("Failed to send map info. ("+tostring(code)+")");
                        retries = retries - 1;
                        delay = 5000;
                        thisErrored = true;
                    }
                }
                sendingMap = false;
            }
        }

        sleep(delay);
    }
}
