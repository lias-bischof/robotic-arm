#pragma once
#include <cJSON.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <cctype>
#include <memory>
#include <stdexcept>
#include <string>

class Json {
    std::unique_ptr<cJSON, decltype(&cJSON_Delete)> value;
public:
    explicit Json(cJSON* p = nullptr) : value(p, cJSON_Delete) {}
    Json(const Json& other) : Json(cJSON_Duplicate(other.get(), true)) {}
    Json& operator=(const Json& other) { if (this != &other) value.reset(cJSON_Duplicate(other.get(), true)); return *this; }
    cJSON* get() const { return value.get(); }
    static Json object() { return Json(cJSON_CreateObject()); }
    static Json array() { return Json(cJSON_CreateArray()); }
    static Json parse(const std::string& text) {
        if (text.find('\0') != std::string::npos) throw std::runtime_error("Invalid JSON");
        Json j(cJSON_ParseWithOpts(text.c_str(), nullptr, true));
        if (!j.get()) throw std::runtime_error("Invalid JSON");
        return j;
    }
    Json operator[](const char* key) const { return Json(cJSON_Duplicate(cJSON_GetObjectItemCaseSensitive(get(), key), true)); }
    Json operator[](int i) const { return Json(cJSON_Duplicate(cJSON_GetArrayItem(get(), i), true)); }
    bool has(const char* key) const { return cJSON_HasObjectItem(get(), key); }
    bool object_type() const { return cJSON_IsObject(get()); }
    bool array_type() const { return cJSON_IsArray(get()); }
    int size() const { return cJSON_GetArraySize(get()); }
    std::string text(const std::string& fallback = "") const {
        return cJSON_IsString(get()) ? get()->valuestring : fallback;
    }
    double number() const {
        if (!cJSON_IsNumber(get()) || !std::isfinite(get()->valuedouble)) throw std::runtime_error("Expected finite number");
        return get()->valuedouble;
    }
    void set(const char* key, const Json& j) { cJSON_DeleteItemFromObjectCaseSensitive(get(), key); cJSON_AddItemToObject(get(), key, cJSON_Duplicate(j.get(), true)); }
    void set(const char* key, const std::string& s) { set(key, Json(cJSON_CreateString(s.c_str()))); }
    void set(const char* key, const char* s) { set(key, std::string(s)); }
    void set(const char* key, double n) { set(key, Json(cJSON_CreateNumber(n))); }
    void set(const char* key, int n) { set(key, double(n)); }
    void set(const char* key, bool b) { set(key, Json(cJSON_CreateBool(b))); }
    void append(const Json& j) { cJSON_AddItemToArray(get(), cJSON_Duplicate(j.get(), true)); }
    std::string dump() const {
        char* p = cJSON_PrintUnformatted(get());
        if (!p) throw std::runtime_error("Cannot encode JSON");
        std::string s(p); cJSON_free(p); return s;
    }
};

constexpr double pi = 3.14159265358979323846;
constexpr int max_pps = 80;
struct Axis { int channel, steps_per_turn; double limit; };
constexpr std::array<Axis, 3> axes{{{1,1600,45}, {2,16000,35}, {4,1600,90}}};
inline int radians_to_steps(double radians, const Axis& axis) {
    if (!std::isfinite(radians) || std::abs(radians) > axis.limit * pi / 180)
        throw std::runtime_error("Angle exceeds per-command limit");
    return int(std::nearbyint(radians * axis.steps_per_turn / (2*pi)));
}
inline Json move(int channel, int steps) {
    auto j = Json::object(); j.set("channel", channel); j.set("steps", steps); return j;
}
inline Json plan(const Json& payload, bool gripper = false) {
    auto moves = Json::array();
    if (payload.has("action") && !cJSON_IsString(payload["action"].get()))
        throw std::runtime_error("action must be a string");
    std::string action = payload["action"].text("none");
    if (gripper) action = payload.object_type() ? payload["action"].text() : payload.text();
    std::transform(action.begin(), action.end(), action.begin(), [](unsigned char c) { return char(std::tolower(c)); });
    if ((gripper && action == "none") || (action != "none" && action != "open" && action != "close"))
        throw std::runtime_error("action must be open or close (or none for calibration)");
    if (!gripper) {
        auto angles = payload.array_type() ? payload : payload["calibration"];
        if (!angles.array_type() || angles.size() != 3) throw std::runtime_error("calibration must contain three angles");
        for (int i = 0; i < 3; ++i) {
            int steps = radians_to_steps(angles[i].number(), axes[i]);
            if (steps) moves.append(move(axes[i].channel, steps));
        }
    }
    if (action != "none") moves.append(move(3, action == "open" ? 80 : -80));
    return moves;
}
inline std::array<int,4> validate_moves(const Json& command) {
    auto moves = command["moves"];
    if (!moves.array_type() || moves.size() < 1 || moves.size() > 4) throw std::runtime_error("Expected 1..4 moves");
    std::array<int,4> steps{}; std::array<bool,4> seen{};
    bool any = false;
    for (int i = 0; i < moves.size(); ++i) {
        double ch = moves[i]["channel"].number(), n = moves[i]["steps"].number();
        if (ch < 1 || ch > 4 || ch != std::floor(ch)) throw std::runtime_error("Invalid channel");
        int index = int(ch)-1;
        if (seen[index] || n != std::floor(n) || std::abs(n) > (ch == 3 ? 300 : 2000)) throw std::runtime_error("Invalid steps or duplicate channel");
        seen[index] = true; steps[index] = int(n); any |= n != 0;
    }
    if (!any) throw std::runtime_error("All steps are zero");
    return steps;
}
