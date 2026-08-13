#include "cpu/cpu_percent_math.h"
#include "power/power_estimator.h"
#include "user/user_filter.h"

#include <string>
#include <vector>
#include <wchar.h>
#include <stdio.h>

static int g_failures = 0;

#define EXPECT_EQ(actual, expected)                                         \
    do {                                                                    \
        const std::string a_ = (actual);                                    \
        const std::string e_ = (expected);                                  \
        if (a_ != e_) {                                                     \
            fprintf(stderr, "FAIL %s:%d: expected '%s' got '%s'\n",        \
                    __FILE__, __LINE__, e_.c_str(), a_.c_str());            \
            ++g_failures;                                                   \
        }                                                                   \
    } while (0)

#define EXPECT_TRUE(cond)                                                   \
    do {                                                                    \
        if (!(cond)) {                                                      \
            fprintf(stderr, "FAIL %s:%d: expected true\n",                 \
                    __FILE__, __LINE__);                                    \
            ++g_failures;                                                   \
        }                                                                   \
    } while (0)

#define EXPECT_FALSE(cond)                                                  \
    do {                                                                    \
        if (cond) {                                                         \
            fprintf(stderr, "FAIL %s:%d: expected false\n",                \
                    __FILE__, __LINE__);                                    \
            ++g_failures;                                                   \
        }                                                                   \
    } while (0)

#define EXPECT_NEAR(actual, expected)                                          \
    do {                                                                       \
        const double a_ = (actual);                                            \
        const double e_ = (expected);                                          \
        if (a_ < e_ - 1e-9 || a_ > e_ + 1e-9) {                                \
            fprintf(stderr, "FAIL %s:%d: expected %g got %g\n",                \
                    __FILE__, __LINE__, e_, a_);                               \
            ++g_failures;                                                      \
        }                                                                      \
    } while (0)

static void test_computeCpuPercent() {
    // All idle: usage is 0.
    auto r = computeCpuPercent(10, 10, 20, 20, 30, 40);
    EXPECT_NEAR(r.usage, 0.0);
    EXPECT_NEAR(r.kernel, 0.0);
    EXPECT_NEAR(r.user, 0.0);

    // 50% busy: 5 kernel + 5  vs 10 idle per interval.
    auto r2 = computeCpuPercent(0, 5, 0, 5, 0, 10);
    EXPECT_NEAR(r2.usage, 50.0);
    EXPECT_NEAR(r2.kernel, 25.0);
    EXPECT_NEAR(r2.user, 25.0);

    // Fully busy: 30 kernel + 30 user, no idle.
    auto r3 = computeCpuPercent(0, 30, 0, 30, 0, 0);
    EXPECT_NEAR(r3.usage, 100.0);
    EXPECT_NEAR(r3.kernel, 50.0);
    EXPECT_NEAR(r3.user, 50.0);

    // Counter reset (new < old) must not produce garbage.
    auto r4 = computeCpuPercent(100, 10, 100, 20, 100, 30);
    EXPECT_NEAR(r4.usage, 0.0);
}

static void test_computePowerUsageLabel() {
    // Zero and negative inputs all clamp to Very Low.
    EXPECT_EQ(computePowerUsageLabel(0.0, 0.0, 0.0), "Very Low");
    EXPECT_EQ(computePowerUsageLabel(-5.0, -5.0, -5.0), "Very Low");

    // A composite just below five stays Very Low.
    EXPECT_EQ(computePowerUsageLabel(8.0, 0.0, 0.0), "Very Low");
    // At a composite of five, the label becomes Low.
    EXPECT_EQ(computePowerUsageLabel(8.4, 0.0, 0.0), "Low");
    // Just below fifteen stays Low.
    EXPECT_EQ(computePowerUsageLabel(24.9, 0.0, 0.0), "Low");
    // At fifteen, the label becomes Moderate.
    EXPECT_EQ(computePowerUsageLabel(25.0, 0.0, 0.0), "Moderate");
    // Just below thirty five stays Moderate.
    EXPECT_EQ(computePowerUsageLabel(58.0, 0.0, 0.0), "Moderate");
    // At thirty five, the label becomes High.
    EXPECT_EQ(computePowerUsageLabel(58.34, 0.0, 0.0), "High");
    // Just below sixty five, combining CPU and GPU, stays High.
    EXPECT_EQ(computePowerUsageLabel(100.0, 16.0, 0.0), "High");
    // At or above sixty five, the label becomes Very High.
    EXPECT_EQ(computePowerUsageLabel(100.0, 16.7, 0.0), "Very High");

    // Disk scores below fifty scale linearly, while fifty and above are capped.
    EXPECT_EQ(computePowerUsageLabel(5.0, 0.0, 90.0), "Low");
    // A moderate disk value stays Low.
    EXPECT_EQ(computePowerUsageLabel(0.0, 0.0, 49.0), "Low");
    // A tiny disk value stays Very Low.
    EXPECT_EQ(computePowerUsageLabel(0.0, 0.0, 2.0), "Very Low");
}

static void test_is_real_user() {
    // Clearly not a real user (empty / well-known system accounts, case-insensitive)
    EXPECT_FALSE(isRealUser(L""));
    EXPECT_FALSE(isRealUser(L"SYSTEM"));
    EXPECT_FALSE(isRealUser(L"system"));
    EXPECT_FALSE(isRealUser(L"LOCAL SERVICE"));
    EXPECT_FALSE(isRealUser(L"NETWORK SERVICE"));
    EXPECT_FALSE(isRealUser(L"DefaultAccount"));
    EXPECT_FALSE(isRealUser(L"Guest"));

    // Non-existent / garbage account
    EXPECT_FALSE(isRealUser(L"definitely.no.such.user.zzz_"));

    // Clearly a real user account on this machine (RID >= 1000)
    EXPECT_TRUE(isRealUser(L"Huzaifa"));
}

static void test_filter_real_users() {
    // Only system and garbage entries means nothing is kept.
    std::vector<std::wstring> none = {L"SYSTEM", L"NETWORK SERVICE", L"noSuchUserX"};
    EXPECT_EQ(filterRealUsers(none).empty() ? std::string("1") : std::string("0"), "1");

    // Mixed: keep only the real user, dedupe, preserve order
    std::vector<std::wstring> mixed = {L"SYSTEM", L"Huzaifa", L"SYSTEM", L"Huzaifa", L"Guest"};
    auto out = filterRealUsers(mixed);
    EXPECT_EQ(out.size() == 1 ? std::string("1") : std::string("0"), "1");
    if (out.size() == 1) {
        EXPECT_TRUE(out[0] == L"Huzaifa");
    }
}

int main() {
    test_computeCpuPercent();
    test_computePowerUsageLabel();
    test_is_real_user();
    test_filter_real_users();

    if (g_failures == 0) {
        printf("ALL TESTS PASSED\n");
        return 0;
    }
    fprintf(stderr, "%d TEST(S) FAILED\n", g_failures);
    return 1;
}