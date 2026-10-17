#include "../protocol.hpp"
#include <cassert>
#include <iostream>
#include <limits>

template<class F> void rejects(F f) {
    bool failed = false;
    try { f(); } catch (const std::exception&) { failed = true; }
    assert(failed);
}
int main() {
    assert(radians_to_steps(pi/6, axes[0]) == 133);
    assert(radians_to_steps(pi/6, axes[1]) == 1333);
    assert(radians_to_steps(pi/2, axes[2]) == 400);
    rejects([] { radians_to_steps(pi/2, axes[0]); });
    rejects([] { radians_to_steps(std::numeric_limits<double>::infinity(), axes[0]); });
    rejects([] { Json::parse("garbage"); });
    rejects([] { Json::parse("[] trailing"); });
    rejects([] { Json::parse(std::string("[]\0{}", 5)); });
    rejects([] { plan(Json::parse("[true,0,0]")); });
    rejects([] { plan(Json::parse("[1e999,0,0]")); });
    rejects([] { plan(Json::parse("[0,0]")); });
    rejects([] { plan(Json::parse("[1,0,0]")); });
    rejects([] { plan(Json::parse("{\"calibration\":[0,0,0],\"action\":\"bad\"}")); });
    auto moves = plan(Json::parse("{\"calibration\":[0.1,0,-0.1],\"action\":\"open\"}"));
    assert(moves.size() == 3);
    assert(moves[0]["channel"].number() == 1 && moves[0]["steps"].number() == 25);
    assert(moves[1]["channel"].number() == 4 && moves[1]["steps"].number() == -25);
    assert(moves[2]["channel"].number() == 3 && moves[2]["steps"].number() == 80);
    assert(plan(Json::parse("[0,0,0]")).size() == 0);
    assert(plan(Json::parse("\"CLOSE\""), true)[0]["steps"].number() == -80);
    for (auto text : {"{\"moves\":[]}", "{\"moves\":[{\"channel\":0,\"steps\":1}]}",
         "{\"moves\":[{\"channel\":1.5,\"steps\":1}]}", "{\"moves\":[{\"channel\":1,\"steps\":1.5}]}",
         "{\"moves\":[{\"channel\":3,\"steps\":301}]}", "{\"moves\":[{\"channel\":2,\"steps\":2001}]}",
         "{\"moves\":[{\"channel\":1,\"steps\":1},{\"channel\":1,\"steps\":2}]}",
         "{\"moves\":[{\"channel\":1,\"steps\":0}]}"})
        rejects([&] { validate_moves(Json::parse(text)); });
    auto command = Json::object(); command.set("moves", moves);
    auto steps = validate_moves(command);
    assert((steps == std::array<int,4>{25,0,80,-25}));
    std::cout << "Protocol tests passed\n";
}
