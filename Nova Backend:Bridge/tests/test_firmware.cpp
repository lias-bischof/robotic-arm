#define NOVA_FIRMWARE_TEST
#include "../firmware/main.cpp"
#include <cassert>

void reset() { all_low(); pulses.fill(0); now_us = input_at = 0; usb_input.clear(); usb_connected = true; }
void check_low() { for (bool high : pins) assert(!high); }
int main() {
    auto cmd = Json::parse(R"({"type":"move","id":"test","max_pps":80,"moves":[{"channel":1,"steps":10},{"channel":2,"steps":-3},{"channel":4,"steps":1}]})");
    reset(); run_move(cmd);
    assert((pulses == std::array<int,4>{10,3,0,1})); check_low();
    reset(); usb_input = "{\"type\":\"stop\"}\n"; input_at = 140000; run_move(cmd);
    assert(pulses[0] > 0 && pulses[0] < 10); check_low();
    reset(); usb_input = "{\"type\":\"stop\"}\n"; run_move(cmd);
    assert(pulses[0] == 0); check_low();
    reset(); usb_connected = false; run_move(cmd);
    assert(pulses[0] == 0); check_low();
    reset(); usb_input = "{\"type\":\"sto"; std::string line;
    assert(!read_line(line)); usb_input = "p\"}\n";
    assert(read_line(line) && Json::parse(line)["type"].text() == "stop");
    reset(); usb_input = std::string(5000, 'x') + "\n";
    bool failed = false;
    try { while (!read_line(line)) {} } catch (const std::exception&) { failed = true; }
    assert(failed); usb_input = "{}\n"; assert(read_line(line) && line == "{}");
    reset(); usb_input = "invalid\n"; input_at = 140000; failed = false;
    try { run_move(cmd); } catch (const std::exception&) { failed = true; }
    assert(failed); check_low();
    puts("Firmware simulation tests passed");
}
