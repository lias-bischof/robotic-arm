#define NOVA_BRIDGE_TEST
#include "../robot_bridge.cpp"
#include <cassert>
#include <vector>

struct Publication { std::string topic, payload; bool retain; };
std::vector<Publication> published;
// Capture MQTT output without opening a network connection.
extern "C" int mosquitto_publish(mosquitto*, int*, const char* topic, int length,
                                 const void* payload, int, bool retain) {
    published.push_back({topic, std::string(static_cast<const char*>(payload), length), retain});
    return MOSQ_ERR_SUCCESS;
}
struct FakePico {
    std::vector<Json> commands;
    void send(const Json& command) { commands.push_back(command); }
};
void send(Bridge<FakePico>& bridge, std::string topic, std::string payload, bool retain = false) {
    mosquitto_message message{};
    message.topic = topic.data(); message.payload = payload.data();
    message.payloadlen = int(payload.size()); message.retain = retain;
    bridge.receive(message);
}
Json receipt(const std::string& id) {
    for (auto it = published.rbegin(); it != published.rend(); ++it)
        if (it->topic == "machine/receipt") {
            auto value = Json::parse(it->payload);
            if (value["id"].text() == id) { assert(!it->retain); return value; }
        }
    throw std::runtime_error("Missing receipt: " + id);
}
int main() {
    mqtt_check(mosquitto_lib_init());
    {
        FakePico pico; Bridge bridge(pico);
        for (auto text : {"READY", "BUSY", "OFFLINE", "invalid", "{}"}) send(bridge, "machine/state", text);
        send(bridge, "machine/state", R"({"id":"retained","payload":""})", true);
        assert(published.empty() && pico.commands.empty());
        send(bridge, "machine/state", R"({"id":"connect","payload":""})");
        assert(pico.commands.size() == 1 && pico.commands.back()["type"].text() == "ping");
        assert(published.empty()); // Wait for actual Pico acknowledgement.
        bridge.event(Json::parse(R"({"event":"ready","id":"connect"})"));
        assert(cJSON_IsTrue(receipt("connect")["ok"].get()));
        assert(receipt("connect")["state"].text() == "READY");
        auto count = published.size();
        send(bridge, "machine/state", "READY"); // Own published notification.
        assert(published.size() == count && pico.commands.size() == 1);
        send(bridge, "machine/calibration", R"({"id":"move","payload":[0.1,0,0]})");
        assert(pico.commands.back()["moves"][0]["steps"].number() == 25);
        count = pico.commands.size();
        send(bridge, "machine/state", R"({"id":"check-busy","payload":""})");
        assert(cJSON_IsTrue(receipt("check-busy")["ok"].get()));
        assert(receipt("check-busy")["state"].text() == "BUSY");
        assert(pico.commands.size() == count); // No ping that could interrupt motion.
        send(bridge, "machine/calibration", R"({"id":"second","payload":[0.1,0,0]})");
        assert(cJSON_IsFalse(receipt("second")["ok"].get()));
        assert(receipt("second")["error"].text() == "Robot is busy");
        bridge.event(Json::parse(R"({"event":"ready","id":"move"})"));
        assert(cJSON_IsTrue(receipt("move")["ok"].get()));
        send(bridge, "machine/calibration", R"({"id":"bad","payload":[3,0,0]})");
        assert(cJSON_IsFalse(receipt("bad")["ok"].get()));
        assert(receipt("bad")["state"].text() == "READY");
        assert(!receipt("bad")["error"].text().empty());
        send(bridge, "machine/stop", R"({"id":"stop","payload":""})");
        assert(receipt("stop")["state"].text() == "BUSY");
        auto stopped = Json::object(); stopped.set("event", "stopped");
        stopped.set("id", pico.commands.back()["id"]); bridge.event(stopped);
        for (const auto& p : published) {
            assert(p.topic != "machine/holding");
            if (p.topic == "machine/state") {
                assert(p.retain);
                assert(p.payload == "READY" || p.payload == "BUSY" || p.payload == "OFFLINE");
            }
        }
    }
    mosquitto_lib_cleanup();
    std::cout << "Frontend MQTT contract tests passed\n";
}
