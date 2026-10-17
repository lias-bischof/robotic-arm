#include "../protocol.hpp"
#include <mosquitto.h>
#include <chrono>
#include <csignal>
#include <fcntl.h>
#include <iostream>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

using Clock = std::chrono::steady_clock;
void check(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
struct Child {
    pid_t pid = -1;
    ~Child() { if (pid > 0) { kill(pid, SIGTERM); waitpid(pid, nullptr, 0); } }
};
struct Harness {
    Child broker, bridge;
    int usb = -1;
    mosquitto* mqtt = nullptr;
    std::string input, motion;
    std::vector<Json> commands, receipts;
    std::vector<std::string> states;
    bool subscribed = false;
    ~Harness() { if (mqtt) mosquitto_destroy(mqtt); if (usb >= 0) close(usb); }
    void reply(const char* event, const std::string& id) {
        auto j = Json::object(); j.set("event", event); j.set("id", id);
        auto data = j.dump() + "\n";
        check(write(usb, data.data(), data.size()) == static_cast<ssize_t>(data.size()), "PTY write failed");
    }
    void tick() {
        check(mosquitto_loop(mqtt, 5, 1) == MOSQ_ERR_SUCCESS, "Test MQTT disconnected");
        char buffer[4096]; auto n = read(usb, buffer, sizeof(buffer));
        if (n > 0) input.append(buffer, n);
        size_t end;
        while ((end = input.find('\n')) != std::string::npos) {
            auto line = input.substr(0, end); input.erase(0, end+1);
            auto cmd = Json::parse(line); commands.push_back(cmd);
            auto type = cmd["type"].text(), id = cmd["id"].text();
            if (type == "ping") reply("ready", id);
            if (type == "move") motion = id;
            if (type == "stop") {
                if (!motion.empty()) { reply("stopped", motion); motion.clear(); }
                else reply("stopped", id);
            }
        }
        usleep(1000);
    }
    template<class F> void until(F condition) {
        auto deadline = Clock::now() + std::chrono::seconds(5);
        while (!condition()) { check(Clock::now() < deadline, "Test timeout"); tick(); }
    }
    void send(const char* topic, const std::string& data) {
        check(mosquitto_publish(mqtt, nullptr, topic, int(data.size()), data.data(), 1, false) == MOSQ_ERR_SUCCESS, "Test publish failed");
    }
    Json receipt(const std::string& id) {
        Json found;
        until([&] { for (const auto& j : receipts) if (j["id"].text() == id) { found = j; return true; } return false; });
        return found;
    }
    void start() {
        // Dedicated broker, no real serial device or production broker involved.
        broker.pid = fork();
        if (broker.pid == 0) { execlp("mosquitto", "mosquitto", "-p", "28883", nullptr); _exit(127); }
        check(broker.pid > 0, "Cannot start test broker");
        mqtt = mosquitto_new(nullptr, true, this);
        check(mqtt != nullptr, "Cannot create test client");
        mosquitto_connect_callback_set(mqtt, [](mosquitto* m, void*, int rc) {
            if (!rc) mosquitto_subscribe(m, nullptr, "machine/#", 1);
        });
        mosquitto_subscribe_callback_set(mqtt, [](mosquitto*, void* ctx, int, int, const int*) {
            static_cast<Harness*>(ctx)->subscribed = true;
        });
        mosquitto_message_callback_set(mqtt, [](mosquitto*, void* ctx, const mosquitto_message* m) {
            auto& h = *static_cast<Harness*>(ctx);
            std::string data(static_cast<const char*>(m->payload), m->payloadlen);
            if (std::string(m->topic) == "machine/receipt") h.receipts.push_back(Json::parse(data));
            if (std::string(m->topic) == "machine/state") h.states.push_back(data);
        });
        int rc = MOSQ_ERR_ERRNO;
        for (int i = 0; i < 100 && rc != MOSQ_ERR_SUCCESS; ++i) { usleep(20000); rc = mosquitto_connect(mqtt, "127.0.0.1", 28883, 30); }
        check(rc == MOSQ_ERR_SUCCESS, "Cannot connect to test broker");
        int status = 0; check(waitpid(broker.pid, &status, WNOHANG) == 0, "Test broker failed (port in use?)");
        usb = posix_openpt(O_RDWR | O_NOCTTY | O_NONBLOCK);
        check(usb >= 0 && grantpt(usb) == 0 && unlockpt(usb) == 0, "Cannot create simulated Pico");
        std::string port = ptsname(usb);
        fcntl(usb, F_SETFD, FD_CLOEXEC);
        bridge.pid = fork();
        if (bridge.pid == 0) { execl("./robot_bridge", "robot_bridge", "--pico-port", port.c_str(), "--mqtt-port", "28883", nullptr); _exit(127); }
        check(bridge.pid > 0, "Cannot start bridge");
        until([&] { return subscribed && !states.empty() && states.back() == "READY"; });
    }
};
int main() {
    try {
        mosquitto_lib_init(); Harness h; h.start();
        h.send("machine/state", R"({"id":"connect","payload":""})");
        check(h.receipt("connect")["state"].text() == "READY", "Frontend handshake failed");
        h.send("machine/calibration", R"({"id":"move-1","payload":[0.1,0,0]})");
        h.until([&] { return h.motion == "move-1"; });
        check(h.commands.back()["moves"][0]["steps"].number() == 25, "Wrong steps");
        h.send("machine/state", R"({"id":"busy","payload":""})");
        check(h.receipt("busy")["state"].text() == "BUSY", "Busy command accepted");
        auto count = h.receipts.size(); h.send("machine/calibration", "invalid");
        h.until([&] { return h.receipts.size() > count; });
        check(cJSON_IsFalse(h.receipts.back()["ok"].get()), "Bad JSON accepted");
        h.send("machine/stop", R"({"id":"stop-1","payload":null})");
        check(h.receipt("stop-1")["state"].text() == "BUSY", "Stop not acknowledged");
        check(h.receipt("move-1")["stopped"].get() && cJSON_IsTrue(h.receipt("move-1")["stopped"].get()), "Motion not stopped");
        h.until([&] { return h.states.back() == "READY"; });
        h.send("machine/gripper", R"({"request_id":"grip","action":"close"})");
        h.until([&] { return h.motion == "grip"; });
        check(h.commands.back()["moves"][0]["steps"].number() == -80, "Wrong gripper motion");
        h.reply("ready", "unrelated");
        h.reply("ready", "grip"); h.motion.clear();
        check(h.receipt("grip")["state"].text() == "READY", "Missing completion");
        h.send("machine/calibration", R"({"id":"zero","payload":[0,0,0]})");
        check(h.receipt("zero")["state"].text() == "READY", "Zero motion rejected");
        h.send("machine/calibration", R"({"id":"limit","payload":[2,0,0]})");
        check(cJSON_IsFalse(h.receipt("limit")["ok"].get()), "Oversized angle accepted");
        h.send("machine/stop", R"({"id":"idle-stop","payload":null})");
        check(h.receipt("idle-stop")["state"].text() == "BUSY", "Idle stop rejected");
        h.until([&] { return h.states.back() == "READY"; });
        h.send("machine/state", R"({"id":"ping","payload":""})");
        check(h.receipt("ping")["state"].text() == "READY", "Ping failed");
        close(h.usb); h.usb = -1;
        int status = 0; auto deadline = Clock::now() + std::chrono::seconds(5);
        while (waitpid(h.bridge.pid, &status, WNOHANG) == 0) { check(Clock::now() < deadline, "Bridge did not exit on USB disconnect"); usleep(10000); }
        h.bridge.pid = -1;
        check(WIFEXITED(status) && WEXITSTATUS(status) != 0, "USB disconnect should fail closed");
        std::cout << "MQTT/USB integration tests passed\n";
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
