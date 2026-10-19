#pragma once

// Recent Xcode toolchains advertise __has_builtin(__yield) but do not
// declare __yield() unless <arm_acle.h> is included explicitly. Qt's
// qyieldcpu.h relies on the declaration, so pull it in before Qt headers.
#if defined(__aarch64__) || defined(__arm__)
#include <arm_acle.h>
#endif
