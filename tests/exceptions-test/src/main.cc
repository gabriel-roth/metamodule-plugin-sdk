// Test plugin for C++ exception and stream support in the MetaModule plugin
// SDK.
//
// Runs a battery of throw/catch and iostream tests at plugin load (init) and
// whenever a module instance is created, printing PASS/FAIL for each to the
// console. get_output(0) reports the result: number of passed tests if all
// passed, negative number of failures otherwise.

#include "CoreModules/CoreProcessor.hh"
#include "CoreModules/elements/element_info.hh"
#include "CoreModules/register_module.hh"

#include <cstdio>
#include <exception>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <memory>
#include <random>
#include <sstream>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

namespace
{

struct TestError : std::runtime_error {
	using std::runtime_error::runtime_error;
};

// Counts destructor executions so tests can verify cleanup during unwinding
struct Tracked {
	int &counter;
	explicit Tracked(int &c)
		: counter{c} {
	}
	~Tracked() {
		counter++;
	}
};

[[gnu::noinline]] void throw_deep(int depth, int &dtors) {
	Tracked t{dtors};
	if (depth > 0)
		throw_deep(depth - 1, dtors);
	else
		throw TestError{"deep"};
}

int run_exception_tests() {
	int passed = 0;
	int failed = 0;
	auto check = [&](bool ok, const char *name) {
		printf("[exc-test] %-32s %s\n", name, ok ? "PASS" : "FAIL");
		ok ? passed++ : failed++;
	};

	{
		bool ok = false;
		try {
			throw 42;
		} catch (int v) {
			ok = (v == 42);
		}
		check(ok, "throw/catch int");
	}

	{
		bool ok = false;
		try {
			throw 3.5;
		} catch (int) {
		} catch (double d) {
			ok = (d == 3.5);
		}
		check(ok, "catch selects matching type");
	}

	{
		bool ok = false;
		try {
			throw TestError{"abc"};
		} catch (std::exception &e) {
			ok = (std::string_view{e.what()} == "abc");
		}
		check(ok, "catch derived via base&, what()");
	}

	{
		bool ok = false;
		std::vector<int> v{1, 2, 3};
		try {
			[[maybe_unused]] auto _ =v.at(99);
		} catch (std::out_of_range &) {
			ok = true;
		}
		check(ok, "vector::at throws out_of_range");
	}

	{
		int dtors = 0;
		bool ok = false;
		try {
			throw_deep(5, dtors);
		} catch (TestError &) {
			ok = (dtors == 6);
		}
		check(ok, "dtors run during unwind");
	}

	{
		bool ok = false;
		try {
			try {
				throw TestError{"rethrown"};
			} catch (...) {
				throw;
			}
		} catch (std::runtime_error &e) {
			ok = (std::string_view{e.what()} == "rethrown");
		}
		check(ok, "rethrow from catch(...)");
	}

	{
		bool ok = false;
		std::exception_ptr ep;
		try {
			throw TestError{"via ptr"};
		} catch (...) {
			ep = std::current_exception();
		}
		if (ep) {
			try {
				std::rethrow_exception(ep);
			} catch (TestError &e) {
				ok = (std::string_view{e.what()} == "via ptr");
			}
		}
		check(ok, "exception_ptr rethrow");
	}

	{
		int seen = -1;
		bool ok = false;
		struct Probe {
			int &out;
			~Probe() {
				out = std::uncaught_exceptions();
			}
		};
		try {
			Probe p{seen};
			throw TestError{"count"};
		} catch (TestError &) {
			ok = (seen == 1);
		}
		check(ok, "uncaught_exceptions in dtor");
	}

	{
		bool ok = false;
		try {
			try {
				throw 1;
			} catch (int) {
				throw TestError{"from handler"};
			}
		} catch (TestError &) {
			ok = true;
		}
		check(ok, "throw from catch handler");
	}

	{
		bool ok = false;
		try {
			throw std::make_unique<int>(7);
		} catch (std::unique_ptr<int> &p) {
			ok = (*p == 7);
		}
		check(ok, "throw move-only object");
	}

	printf("[exc-test] %d passed, %d failed\n", passed, failed);
	return failed ? -failed : passed;
}

int run_stream_tests() {
	int passed = 0;
	int failed = 0;
	auto check = [&](bool ok, const char *name) {
		printf("[stream-test] %-32s %s\n", name, ok ? "PASS" : "FAIL");
		ok ? passed++ : failed++;
	};

	{
		std::ostringstream oss;
		oss << "x=" << 42 << " y=" << std::fixed << std::setprecision(2) << 3.14159 << " hex=" << std::hex << 255;
		check(oss.str() == "x=42 y=3.14 hex=ff", "ostringstream formatting");
	}

	{
		std::istringstream iss{"123 4.5 hello"};
		int i{};
		double d{};
		std::string s;
		iss >> i >> d >> s;
		check(i == 123 && d == 4.5 && s == "hello" && !iss.fail(), "istringstream parsing");
	}

	{
		std::istringstream iss{"notanumber"};
		int i = 0;
		iss >> i;
		check(iss.fail(), "failbit set on bad parse");
	}

	{
		std::istringstream iss{"line one\nline two\n"};
		std::string a, b;
		std::getline(iss, a);
		std::getline(iss, b);
		check(a == "line one" && b == "line two", "getline");
	}

	{
		std::stringstream ss;
		ss << -17 << ' ' << "words";
		int i{};
		std::string w;
		ss >> i >> w;
		check(i == -17 && w == "words", "stringstream round-trip");
	}

	{
		bool ok = false;
		std::istringstream iss{"abc"};
		iss.exceptions(std::ios::failbit);
		try {
			int i{};
			iss >> i;
		} catch (std::ios_base::failure &) {
			ok = true;
		} catch (...) {
		}
		check(ok, "stream throws ios_base::failure");
	}

	{
		std::cout << "[stream-test] hello from std::cout" << std::endl;
		std::cerr << "[stream-test] hello from std::cerr\n";
		check(std::cout.good(), "cout/cerr writable");
	}

	{
		std::ifstream f{"nonexistent-file-xyz.txt"};
		check(!f.is_open() && f.fail(), "ifstream missing file fails cleanly");
	}

	{
		// Filesystem may not be writable from a plugin's working directory;
		// pass if the file round-trips or if the open fails cleanly.
		std::ofstream out{"usb:/exc-test-scratch.txt"};
		if (out.is_open()) {
			out << "roundtrip " << 99;
			out.close();
			std::ifstream in{"usb:/exc-test-scratch.txt"};
			std::string word;
			int num{};
			in >> word >> num;
			// note: the scratch file is left behind; the host does not
			// provide an unlink/remove syscall
			check(word == "roundtrip" && num == 99, "fstream write/read round-trip");
		} else {
			printf("[stream-test] (fs not writable, skipping fstream round-trip)\n");
			check(true, "ofstream unwritable fails cleanly");
		}
	}

	{
		check(std::to_string(42) == "42" && std::stoi("-7") == -7, "to_string/stoi");
	}

	{
		// std::random_device is widely used by ported VCV modules. On this
		// platform it falls back to a PRNG; the important thing is that it
		// links (a misconfigured libstdc++ makes it reference getentropy,
		// which the firmware does not provide) and produces values.
		std::random_device rd;
		std::mt19937 gen{rd()};
		std::uniform_int_distribution<int> dist{1, 6};
		int v = dist(gen);
		check(v >= 1 && v <= 6, "random_device/mt19937");
	}

	printf("[stream-test] %d passed, %d failed\n", passed, failed);
	return failed ? -failed : passed;
}

int run_all_tests() {
	int exc = run_exception_tests();
	int strm = run_stream_tests();
	if (exc < 0 || strm < 0)
		return (exc < 0 ? exc : 0) + (strm < 0 ? strm : 0);
	return exc + strm;
}

class ExcTestCore : public CoreProcessor {
public:
	ExcTestCore() {
		printf("[exc-test] module created: running exception + stream tests\n");
		result = run_all_tests();
	}

	void update() override {
	}
	void set_samplerate(float) override {
	}
	void set_param(int, float) override {
	}
	void set_input(int, float) override {
	}
	float get_output(int output_id) const override {
		return output_id == 0 ? static_cast<float>(result) : 0.f;
	}

private:
	int result = 0;
};

struct ExcTestInfo : MetaModule::ModuleInfoBase {
	static constexpr std::string_view slug{"ExcTest"};
	static constexpr std::string_view description{"C++ Exceptions Test"};
	static constexpr uint32_t width_hp = 4;
	static constexpr std::string_view png_filename{"exceptions-test/panel.png"};
};

} // namespace

extern "C" __attribute__((visibility("default"))) void init() {
	printf("[exc-test] plugin loaded: running exception + stream tests\n");
	run_all_tests();
	MetaModule::register_module<ExcTestCore, ExcTestInfo>("ExceptionsTest");
}
