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

mat3 DirUpLeftToMat(const vec3 &in dir, const vec3 &in up, const vec3 &in left) {
    return mat3(left, up, dir);
}

Json::Value@ Vec3ToJson(const vec3 &in v) {
    auto @j = Json::Object();
    j['x'] = v.x;
    j['y'] = v.y;
    j['z'] = v.z;
    return j;
}

Json::Value@ QuatToJson(const quat &in q) {
    auto @j = Json::Object();
    j['x'] = q.x;
    j['y'] = q.y;
    j['z'] = q.z;
    j['w'] = q.w;
    return j;
}

void Main(){
	auto app = cast<CTrackMania>(GetApp());

    string currentMapUid = "";
    bool sendingMap = false;
    int maxDelay = 5000;
    int currentDelay = 0;
    int stepDelay = 200;
    int lastHeight = 0;
    Json::Value lastSaved = Json::Object();
    Json::Value payload = Json::Object();
    int saved = 0;

    while(true){
        auto map = app.RootMap;
        CTrackManiaNetwork@ network;
        auto PlaygroundClientScriptAPI = app.Network.PlaygroundClientScriptAPI;
        
        if(enabled && map !is null && map.MapInfo.MapUid != "" && app.Editor is null){
            auto mapUid = map.MapInfo.MapUid;
            if(currentMapUid != mapUid){
                print("Map changed. (old: "+tostring(currentMapUid)+" new: " + tostring(mapUid) +")");
                currentMapUid = mapUid;
            }
        } else if(enabled) {
            currentMapUid = "";

        }
        string name = '';
        try {
            name = app.LocalPlayerInfo.Name;
        } catch {
            name = '';
        }
        if(enabled && currentMapUid != "" && currentMapUid == mapUid && !PlaygroundClientScriptAPI.IsInGameMenuDisplayed && name != ''){
	        auto visState = VehicleState::ViewingPlayerState();
            int currentHeight = visState.Position.y;
            if(currentHeight > lastHeight){
                lastHeight = currentHeight;
                auto @j = Json::Object();
                j["pos"] = Vec3ToJson(visState.Position);
                j["rotq"] = QuatToJson(quat(DirUpLeftToMat(visState.Dir, visState.Up, visState.Left)));
                j["vel"] = Vec3ToJson(visState.WorldVel);
                j["mapName"] = tostring(StripFormatCodes(map.MapInfo.Name));
                j["player"] = name;
                j["mapUid"] = currentMapUid;
                lastSaved = j;
            }
            if(currentDelay >= maxDelay){
                print("Saving new data...");
                currentDelay = 0;
                if(sendingMap == false){
                    sendingMap = true;
                    string time = tostring(Time::get_Stamp());
                    payload[time] = lastSaved;
                    lastSaved = Json::Object();
                    lastHeight = 0;
                    saved = saved + 1;
                    if(saved == 5){
                        try{
                            print("Sending map info. ("+tostring(currentMapUid)+")");
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
        }

        currentDelay += stepDelay;
        sleep(stepDelay);
    }
}
