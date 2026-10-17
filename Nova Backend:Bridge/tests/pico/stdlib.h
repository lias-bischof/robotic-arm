#pragma once
#include <array>
#include <cstdint>
#include <string>
constexpr int PICO_ERROR_TIMEOUT = -1;
inline std::array<bool,8> pins{};
inline std::array<int,4> pulses{};
inline uint64_t now_us = 0, input_at = 0;
inline std::string usb_input;
inline bool usb_connected = true;
inline void gpio_put(int pin, bool high) {
    if (pin % 2 == 0 && high && !pins[pin]) ++pulses[pin/2];
    pins[pin] = high;
}
inline int getchar_timeout_us(int) {
    if (now_us < input_at || usb_input.empty()) return PICO_ERROR_TIMEOUT;
    int c = static_cast<unsigned char>(usb_input[0]); usb_input.erase(0,1); return c;
}
inline void sleep_us(uint64_t n) { now_us += n; }
inline void sleep_ms(uint64_t n) { now_us += n*1000; }
