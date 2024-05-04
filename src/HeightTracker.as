[Setting category="Info" name="Enabled"]
bool enabled = false;

[Setting category="Info" name="Endpoint"]
string endpointUrl = "";

[Setting category="Info" name="mapUid"]
string mapUid = "";


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

    string currentMapUid = "";
    bool sendingMap = false;
    int delay = 5000;
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
            }
        } else if(enabled) {
            currentMapUid = "";
        }
        if(enabled && currentMapUid != "" && currentMapUid == mapUid && TMData.PlayerState == PlayerState::EPlayerState_Driving && !TMData.IsPaused){
	        auto visState = VehicleState::ViewingPlayerState();
            if(sendingMap == false){
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
                    try{
                        print("Sending map info. ("+tostring(currentMapUid)+")");
                        string STATS_FILE = IO::FromDataFolder("PluginStorage/dips-plus-plus/stats.json");
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
                        } else {
                            print("Failed to send map info. ("+tostring(code)+")");
                        }
                        saved = 0;
                        sendingMap = false;
                    } catch {
                        warn("exception sending data to API: " + getExceptionInfo());
                        sendingMap = false;
                    }
                }
                sendingMap = false;
            }
        }

        sleep(delay);
    }
}
