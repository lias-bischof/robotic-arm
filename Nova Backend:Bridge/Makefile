CXX ?= c++
CPPFLAGS ?=
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -pedantic
LDFLAGS ?=
LDLIBS ?= -lmosquitto -lcjson

LIBMOSQUITTO_CFLAGS := $(shell pkg-config --cflags libmosquitto 2>/dev/null)
LIBMOSQUITTO_LIBS := $(shell pkg-config --libs libmosquitto 2>/dev/null)
LIBCJSON_CFLAGS := $(shell pkg-config --cflags libcjson 2>/dev/null)
LIBCJSON_LIBS := $(shell pkg-config --libs libcjson 2>/dev/null)

CPPFLAGS += $(LIBMOSQUITTO_CFLAGS) $(LIBCJSON_CFLAGS)
CPPFLAGS += -I.
MOSQ_LIBS = $(if $(strip $(LIBMOSQUITTO_LIBS)),$(LIBMOSQUITTO_LIBS),-lmosquitto)
CJSON_LIBS = $(if $(strip $(LIBCJSON_LIBS)),$(LIBCJSON_LIBS),-lcjson)

BRIDGE = robot_bridge
TEST_PROTOCOL = tests/test_protocol
TEST_FIRMWARE = tests/test_firmware
TEST_CONTRACT = tests/test_mqtt_contract
TEST_BRIDGE = tests/test_bridge
TESTS = $(TEST_PROTOCOL) $(TEST_FIRMWARE) $(TEST_CONTRACT) $(TEST_BRIDGE)

.PHONY: all test clean

all: $(BRIDGE)

$(BRIDGE): robot_bridge.cpp protocol.hpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ robot_bridge.cpp $(LDFLAGS) $(MOSQ_LIBS) $(CJSON_LIBS)

$(TEST_PROTOCOL): tests/test_protocol.cpp protocol.hpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ tests/test_protocol.cpp $(LDFLAGS) $(CJSON_LIBS)

$(TEST_FIRMWARE): tests/test_firmware.cpp firmware/main.cpp protocol.hpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -Itests -o $@ tests/test_firmware.cpp $(LDFLAGS) $(CJSON_LIBS)

$(TEST_CONTRACT): tests/test_mqtt_contract.cpp robot_bridge.cpp protocol.hpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ tests/test_mqtt_contract.cpp $(LDFLAGS) $(MOSQ_LIBS) $(CJSON_LIBS)

$(TEST_BRIDGE): tests/test_bridge.cpp protocol.hpp $(BRIDGE)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ tests/test_bridge.cpp $(LDFLAGS) $(MOSQ_LIBS) $(CJSON_LIBS)

test: $(TESTS)
	./$(TEST_PROTOCOL)
	./$(TEST_FIRMWARE)
	./$(TEST_CONTRACT)
	./$(TEST_BRIDGE)

clean:
	rm -f $(BRIDGE) $(TESTS)
