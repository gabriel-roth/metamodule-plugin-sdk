// Lightweight replacement for libsupc++'s vterminate.cc.
//
// The original __verbose_terminate_handler demangles the exception type name
// with __cxa_demangle, which would pull cp-demangle.c (~100 kB of code) into
// every plugin. This version prints the mangled name instead (run it through
// c++filt on the host to decode). Everything else matches the original:
// it is installed as the default terminate_handler by eh_term_handler.cc
// (via _GLIBCXX_VERBOSE), prints what() if the exception derives from
// std::exception, then aborts.

#include <bits/c++config.h>
#include <bits/exception_defines.h>
#include <cstdio>
#include <cstdlib>
#include <cxxabi.h>
#include <exception>

using namespace std;
using namespace abi;

namespace __gnu_cxx
{
_GLIBCXX_BEGIN_NAMESPACE_VERSION

void __verbose_terminate_handler() {
	static bool terminating;
	if (terminating) {
		fputs("terminate called recursively\n", stderr);
		abort();
	}
	terminating = true;

	// Make sure there was an exception; terminate is also called for an
	// attempt to rethrow when there is no suitable exception.
	type_info *t = __cxa_current_exception_type();
	if (t) {
		fputs("terminate called after throwing an instance of '", stderr);
		fputs(t->name(), stderr);
		fputs("'\n", stderr);

		// If the exception is derived from std::exception, we can
		// give more information.
		__try {
			__throw_exception_again;
		}
		__catch(const exception &exc) {
			fputs("  what():  ", stderr);
			fputs(exc.what(), stderr);
			fputs("\n", stderr);
		}
		__catch(...) {
		}
	} else
		fputs("terminate called without an active exception\n", stderr);

	abort();
}

_GLIBCXX_END_NAMESPACE_VERSION
} // namespace __gnu_cxx
