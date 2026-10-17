#include "protocol.hpp"
#include "pico/stdlib.h"
#include "pico/stdio_usb.h"
#include <cstdio>

void all_low() { for (int pin = 0; pin < 8; ++pin) gpio_put(pin, false); }
void emit(const char* event, const std::string& id, const Json& details = Json::object()) {
    auto message = details; message.set("event", event); message.set("id", id);
    puts(message.dump().c_str());
}
bool read_line(std::string& line) {
    static std::string input;
    static bool overflow = false;
    for (int count = 0; count < 4096; ++count) {
        int c = getchar_timeout_us(0);
        if (c == PICO_ERROR_TIMEOUT) return false;
        if (c == '\r') continue;
        if (c == '\n') {
            line.swap(input); input.clear();
            bool too_long = overflow; overflow = false;
            if (too_long) throw std::runtime_error("USB command too long");
            return true;
        }
        if (input.size() < 4096) input += char(c); else overflow = true;
    }
    return false;
}
bool stop_requested() {
    if (!stdio_usb_connected()) return true;
    std::string line;
    if (!read_line(line)) return false;
    auto message = Json::parse(line);
    if (message["type"].text() == "stop") return true;
    auto detail = Json::object(); detail.set("message", "Robot is busy");
    emit("error", message["id"].text("unknown"), detail);
    return false;
}
void run_move(const Json& command) {
    auto steps = validate_moves(command);
    auto id = command["id"].text("unknown");
    double speed = command.has("max_pps") ? command["max_pps"].number() : 250;
    int peak = int(std::clamp(speed, 40.0, 500.0));
    int total = 0;
    std::array<int,4> accumulated{}, executed{};
    for (int n : steps) total = std::max(total, std::abs(n));
    all_low();
    for (int i = 0; i < 4; ++i) gpio_put(2*i+1, steps[i] > 0);
    struct ResetPins { ~ResetPins() { all_low(); } } reset;
    auto result = [&]() {
        auto counts = Json::object();
        for (int i = 0; i < 4; ++i) if (steps[i]) counts.set(std::to_string(i+1).c_str(), executed[i]);
        auto detail = Json::object(); detail.set("executed", counts); return detail;
    };
    for (int i = 0; i < 10; ++i) {
        if (stop_requested()) { all_low(); emit("stopped", id, result()); return; }
        sleep_ms(10);
    }
    auto busy = Json::object(); busy.set("ticks", total); busy.set("max_pps", peak);
    emit("busy", id, busy);
    for (int tick = 0; tick < total; ++tick) {
        if (stop_requested()) { all_low(); emit("stopped", id, result()); return; }
        int ramp = std::min({tick+1, total-tick, 120});
        int half_period = int(500000 / (40 + (peak-40) * ramp / 120.0));
        std::array<bool,4> pulse{};
        for (int i = 0; i < 4; ++i) {
            accumulated[i] += std::abs(steps[i]);
            if (accumulated[i] >= total) {
                accumulated[i] -= total; pulse[i] = true; gpio_put(2*i, true);
            }
        }
        sleep_us(half_period);
        for (int i = 0; i < 4; ++i) if (pulse[i]) { gpio_put(2*i, false); ++executed[i]; }
        sleep_us(half_period);
        if (tick == 0 || (tick+1)%250 == 0 || tick == total-1) {
            auto progress = Json::object(); progress.set("tick", tick+1); progress.set("total", total);
            emit("progress", id, progress);
        }
    }
    all_low(); emit("ready", id, result());
}
void handle(const Json& command) {
    auto id = command["id"].text("unknown"), type = command["type"].text();
    if (type == "move") run_move(command);
    else if (type == "stop") { all_low(); emit("stopped", id); }
    else if (type == "ping") {
        all_low(); auto detail = Json::object();
        detail.set("firmware", "nova-pico-cpp-1"); detail.set("channels", 4); emit("ready", id, detail);
    } else throw std::runtime_error("Unknown command type");
}
#ifndef NOVA_FIRMWARE_TEST
int main() {
    for (int pin = 0; pin < 8; ++pin) { gpio_init(pin); gpio_set_dir(pin, GPIO_OUT); }
    all_low(); stdio_init_all();
    emit("boot", "boot");
    while (true) {
        std::string id = "unknown", line;
        try {
            if (!read_line(line)) { sleep_ms(1); continue; }
            auto command = Json::parse(line); id = command["id"].text(id); handle(command);
        } catch (const std::exception& error) {
            all_low(); auto detail = Json::object(); detail.set("message", error.what()); emit("error", id, detail);
        }
    }
}
#endif
