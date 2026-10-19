#pragma once

#include <atomic>

// Lets one thread stop a blocking request running on another. Network calls
// that take a token check it while they wait and fail promptly once it is
// cancelled. A token can't be reset; use a new one for the next request.
class CancellationToken {
public:
    void cancel()
    {
        m_Cancelled.store(true, std::memory_order_relaxed);
    }

    bool isCancelled() const
    {
        return m_Cancelled.load(std::memory_order_relaxed);
    }

private:
    std::atomic<bool> m_Cancelled{false};
};

// True if `token` was given and has been cancelled.
inline bool isCancelled(const CancellationToken* token)
{
    return token != nullptr && token->isCancelled();
}

constexpr const char* kCancelledError = "The request was cancelled";
