#include "protocol.hpp"
#include <mosquitto.h>
#include <chrono>
#include <csignal>
#include <cstring>
#include <fcntl.h>
#include <glob.h>
#include <iostream>
#include <poll.h>
#include <termios.h>
#include <unistd.h>

using Clock = std::chrono::steady_clock;
volatile std::sig_atomic_t quitting = 0;
void signal_handler(int) { quitting = 1; }
void mqtt_check(int rc) { if (rc != MOSQ_ERR_SUCCESS) throw std::runtime_error(mosquitto_strerror(rc)); }
std::string new_id() {
    static unsigned sequence = 0;
    return "bridge-" + std::to_string(getpid()) + "-" + std::to_string(++sequence);
}
Json command(const char* type, const std::string& id) {
    auto j = Json::object(); j.set("type", type); j.set("id", id); return j;
}
std::string discover_port() {
    glob_t paths{};
    glob("/dev/cu.usbmodem*", 0, nullptr, &paths);
    glob("/dev/ttyACM*", GLOB_APPEND, nullptr, &paths);
    std::string port = paths.gl_pathc == 1 ? paths.gl_pathv[0] : "";
    globfree(&paths);
    if (port.empty()) throw std::runtime_error("Specify --pico-port: no unique Pico USB port found");
    return port;
}
class Serial {
    int fd;
    std::string input;
public:
    explicit Serial(const std::string& port) {
        fd = open(port.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
        if (fd < 0) throw std::runtime_error("Cannot open " + port + ": " + strerror(errno));
        termios settings{};
        if (tcgetattr(fd, &settings) != 0) { close(fd); throw std::runtime_error("Cannot read serial settings"); }
        cfmakeraw(&settings);
        cfsetispeed(&settings, B115200); cfsetospeed(&settings, B115200);
        settings.c_cflag |= CLOCAL | CREAD;
        settings.c_cflag &= ~CRTSCTS;
        settings.c_cc[VMIN] = 0; settings.c_cc[VTIME] = 0;
        if (tcsetattr(fd, TCSANOW, &settings) != 0) { close(fd); throw std::runtime_error("Cannot configure serial port"); }
        tcflush(fd, TCIOFLUSH);
    }
    ~Serial() { close(fd); }
    void send(const Json& message) {
        auto data = message.dump() + "\n";
        auto deadline = Clock::now() + std::chrono::seconds(2);
        size_t offset = 0;
        while (offset < data.size()) {
            auto n = write(fd, data.data() + offset, data.size()-offset);
            if (n > 0) offset += size_t(n);
            else if (n < 0 && errno != EAGAIN && errno != EINTR) throw std::runtime_error("USB write failed");
            else { pollfd p{fd, POLLOUT, 0}; poll(&p, 1, 10); }
            if (Clock::now() > deadline) throw std::runtime_error("USB write timeout");
        }
    }
    template<class Handler> void read_lines(Handler handler) {
        pollfd p{fd, POLLIN, 0};
        if (poll(&p, 1, 0) < 0 && errno != EINTR) throw std::runtime_error("USB poll failed");
        if (p.revents & (POLLERR | POLLHUP | POLLNVAL)) throw std::runtime_error("Pico disconnected");
        char buffer[2048];
        auto n = read(fd, buffer, sizeof(buffer));
        if (n < 0 && errno != EAGAIN && errno != EINTR) throw std::runtime_error("USB read failed");
        if (n > 0) input.append(buffer, size_t(n));
        size_t end;
        while ((end = input.find('\n')) != std::string::npos) {
            auto line = input.substr(0, end); input.erase(0, end+1);
            Json event;
            try { event = Json::parse(line); }
            catch (const std::exception&) { std::cerr << "Ignoring non-JSON Pico output\n"; continue; }
            handler(event);
        }
        if (input.size() > 8192) throw std::runtime_error("Pico line too long");
    }
};
template<class Pico = Serial>
class Bridge {
    Pico& pico;
    std::unique_ptr<mosquitto, decltype(&mosquitto_destroy)> client;
    std::string active, stop_id, fatal;
    Clock::time_point deadline{}, stop_deadline{};
    bool connected = false;
public:
    explicit Bridge(Pico& serial) : pico(serial), client(mosquitto_new(nullptr, true, this), mosquitto_destroy) {
        if (!client) throw std::runtime_error("Cannot create MQTT client");
        mqtt_check(mosquitto_will_set(client.get(), "machine/state", 7, "OFFLINE", 1, true));
        mosquitto_connect_callback_set(client.get(), [](mosquitto*, void* context, int rc) {
            auto& b = *static_cast<Bridge*>(context);
            try {
                if (rc) throw std::runtime_error("Broker rejected connection");
                for (auto topic : {"machine/state", "machine/calibration", "machine/gripper", "machine/stop"})
                    mqtt_check(mosquitto_subscribe(b.client.get(), nullptr, topic, 1));
                b.connected = true; b.state("READY");
            } catch (const std::exception& e) { b.fatal = e.what(); }
        });
        mosquitto_message_callback_set(client.get(), [](mosquitto*, void* context, const mosquitto_message* m) {
            auto& b = *static_cast<Bridge*>(context);
            try { b.receive(*m); } catch (const std::exception& e) { b.fatal = e.what(); }
        });
    }
    void publish(const char* topic, const std::string& data, bool retain = false) {
        mqtt_check(mosquitto_publish(client.get(), nullptr, topic, int(data.size()), data.data(), 1, retain));
    }
    void state(const char* name, const std::string& id = "", const Json& details = Json::object()) {
        publish("machine/state", name, true);
        auto j = details; j.set("state", name); j.set("request_id", id);
        j.set("timestamp", std::chrono::duration<double>(std::chrono::system_clock::now().time_since_epoch()).count());
        publish("machine/status", j.dump());
    }
    void receipt(const std::string& id, bool ok, const char* name, const Json& details = Json::object()) {
        auto j = details; j.set("id", id); j.set("ok", ok); j.set("state", name);
        publish("machine/receipt", j.dump());
    }
    void receive(const mosquitto_message& m) {
        std::string topic(m.topic), id = new_id();
        // State requests and retained/plain status notifications share one topic.
        if (topic == "machine/state") {
            if (m.retain || m.payloadlen > 8192) return;
            try {
                auto request = Json::parse(std::string(static_cast<const char*>(m.payload ? m.payload : ""), m.payloadlen));
                if (!request.has("payload") || request["id"].text().empty()) return;
            } catch (const std::exception&) { return; }
        } else if (topic != "machine/calibration" && topic != "machine/gripper" && topic != "machine/stop") return;
        Json payload;
        bool sending = false;
        try {
            if (m.payloadlen > 8192) throw std::runtime_error("MQTT payload too large");
            try {
                payload = Json::parse(std::string(static_cast<const char*>(m.payload ? m.payload : ""), m.payloadlen));
                if (payload.has("id") && payload.has("payload")) {
                    id = payload["id"].text(id); payload = payload["payload"];
                } else id = payload["request_id"].text(id);
            } catch (const std::exception&) { if (topic != "machine/stop") throw; }
            if (m.retain && topic != "machine/state") throw std::runtime_error("Retained commands are rejected");
            if (topic == "machine/stop") {
                if (stop_id.empty()) {
                    sending = true; stop_id = new_id(); pico.send(command("stop", stop_id));
                    stop_deadline = Clock::now() + std::chrono::seconds(2);
                }
                state("BUSY", id); receipt(id, true, "BUSY"); return;
            }
            if (!active.empty() || !stop_id.empty()) {
                auto detail = Json::object();
                if (topic != "machine/state") detail.set("error", "Robot is busy");
                receipt(id, topic == "machine/state", "BUSY", detail); return;
            }
            auto cmd = command(topic == "machine/state" ? "ping" : "move", id);
            if (topic != "machine/state") {
                auto moves = plan(payload, topic == "machine/gripper");
                if (!moves.size()) { state("READY", id); receipt(id, true, "READY"); return; }
                cmd.set("moves", moves); cmd.set("max_pps", max_pps);
                state("BUSY", id);
            }
            sending = true; active = id; pico.send(cmd);
            deadline = Clock::now() + std::chrono::seconds(topic == "machine/state" ? 5 : 120);
        } catch (const std::exception& e) {
            auto detail = Json::object(); detail.set("error", e.what());
            receipt(id, false, sending ? "OFFLINE" : (!active.empty() || !stop_id.empty() ? "BUSY" : "READY"), detail);
            if (sending) throw;
            if (stop_id.empty() && active.empty()) state("READY", id, detail);
        }
    }
    void event(const Json& event) {
        publish("machine/telemetry", event.dump());
        auto id = event["id"].text(), kind = event["event"].text();
        if (kind != "ready" && kind != "error" && kind != "stopped") return;
        if (!active.empty() && id == active) {
            bool ok = kind != "error";
            auto details = Json::object();
            if (event.has("executed")) details.set("executed", event["executed"]);
            if (kind == "stopped") details.set("stopped", true);
            if (!ok) details.set("error", event["message"].text("Pico error"));
            if (kind == "stopped") stop_id.clear();
            receipt(active, ok, ok ? "READY" : "OFFLINE", details);
            state(stop_id.empty() ? (ok ? "READY" : "OFFLINE") : "BUSY", active, details);
            active.clear();
            if (!ok) throw std::runtime_error(event["message"].text("Pico error"));
        } else if (!stop_id.empty() && id == stop_id) {
            if (kind != "stopped") throw std::runtime_error("Pico failed to stop");
            stop_id.clear(); if (active.empty()) state("READY", id);
        }
    }
    void run(const std::string& host, int port) {
        mqtt_check(mosquitto_connect(client.get(), host.c_str(), port, 30));
        auto connect_deadline = Clock::now() + std::chrono::seconds(5);
        try {
            while (!quitting) {
                mqtt_check(mosquitto_loop(client.get(), 10, 1));
                if (!fatal.empty()) throw std::runtime_error(fatal);
                pico.read_lines([&](const Json& j) { event(j); });
                auto now = Clock::now();
                if ((!connected && now > connect_deadline) || (!active.empty() && now > deadline) || (!stop_id.empty() && now > stop_deadline))
                    throw std::runtime_error("Response timeout; stopping bridge");
            }
        } catch (...) { shutdown(); throw; }
        shutdown();
    }
    void shutdown() noexcept {
        try { pico.send(command("stop", new_id())); } catch (...) {}
        try {
            state("OFFLINE");
            for (int i = 0; i < 10; ++i) { mosquitto_loop_write(client.get(), 1); usleep(1000); }
        } catch (...) {}
        mosquitto_disconnect(client.get());
    }
};
#ifndef NOVA_BRIDGE_TEST
int main(int argc, char** argv) {
    try {
        std::string host = "127.0.0.1", port;
        int mqtt_port = 1883;
        for (int i = 1; i < argc; ++i) {
            std::string arg = argv[i];
            if (arg == "--help") { std::cout << "robot_bridge [--broker HOST] [--mqtt-port PORT] [--pico-port DEVICE]\nUSB: 115200 baud\n"; return 0; }
            if (++i >= argc) throw std::runtime_error("Missing option value");
            if (arg == "--broker") host = argv[i];
            else if (arg == "--pico-port") port = argv[i];
            else if (arg == "--mqtt-port") {
                size_t used; std::string value = argv[i]; mqtt_port = std::stoi(value, &used);
                if (used != value.size() || mqtt_port < 1 || mqtt_port > 65535) throw std::runtime_error("Invalid MQTT port");
            } else throw std::runtime_error("Unknown option: " + arg);
        }
        if (port.empty()) port = discover_port();
        std::signal(SIGINT, signal_handler); std::signal(SIGTERM, signal_handler);
        Serial pico(port);
        auto id = new_id(); bool ready = false;
        pico.send(command("ping", id));
        auto deadline = Clock::now() + std::chrono::seconds(5);
        while (!ready && !quitting && Clock::now() < deadline) {
            pico.read_lines([&](const Json& event) { if (event["id"].text() == id && event["event"].text() == "ready") ready = true; });
            usleep(10000);
        }
        if (quitting) return 0;
        if (!ready) throw std::runtime_error("Pico handshake failed");
        mqtt_check(mosquitto_lib_init());
        { Bridge bridge(pico); std::cerr << "NOVA bridge: " << port << " -> " << host << ':' << mqtt_port << '\n'; bridge.run(host, mqtt_port); }
        mosquitto_lib_cleanup();
        return 0;
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}

#endif
