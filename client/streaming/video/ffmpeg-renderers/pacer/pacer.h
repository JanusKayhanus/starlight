#pragma once

#include "../../decoder.h"
#include "../renderer.h"

#include <condition_variable>
#include <deque>
#include <mutex>

// The maximum number of frames pacer will ever hold is:
// - 3 frames in the pacing queue
// - 1 frame removed from the render queue in the process of rendering
// - 1 frame for deferred free
#define PACER_MAX_OUTSTANDING_FRAMES (3 + 1 + 1)

class IVsyncSource {
public:
    virtual ~IVsyncSource() {}
    virtual bool initialize(SDL_Window* window, int displayFps) = 0;

    // Asynchronous sources produce callbacks on their own, while synchronous
    // sources require calls to waitForVsync().
    virtual bool isAsync() = 0;

    virtual void waitForVsync() {
        // Synchronous sources must implement waitForVsync()!
        SDL_assert(false);
    }
};

class Pacer
{
public:
    Pacer(IFFmpegRenderer* renderer, PVIDEO_STATS videoStats);

    ~Pacer();

    void submitFrame(AVFrame* frame);

    bool initialize(SDL_Window* window, int maxVideoFps, bool enablePacing);

    void signalVsync();

    void renderOnMainThread();

    // Returns a new reference to the most recently rendered frame, or nullptr.
    // The caller must free it with av_frame_free().
    AVFrame* cloneLastRenderedFrame();

private:
    static int vsyncThread(void* context);

    static int renderThread(void* context);

    void handleVsync(int timeUntilNextVsyncMillis);

    void enqueueFrameForRenderingAndUnlock(AVFrame* frame);

    void renderFrame(AVFrame* frame);

    void dropFrameForEnqueue(std::deque<AVFrame*>& queue);

    std::deque<AVFrame*> m_RenderQueue;
    std::deque<AVFrame*> m_PacingQueue;
    std::deque<int> m_PacingQueueHistory;
    std::deque<int> m_RenderQueueHistory;
    std::mutex m_FrameQueueLock;
    std::condition_variable m_RenderQueueNotEmpty;
    std::condition_variable m_PacingQueueNotEmpty;
    std::condition_variable m_VsyncSignalled;
    SDL_Thread* m_RenderThread;
    SDL_Thread* m_VsyncThread;
    // The most recently rendered frame, held until the next one is rendered
    AVFrame* m_DeferredFreeFrame;
    std::mutex m_DeferredFreeFrameLock;
    bool m_FirstFrameRendered;
    bool m_Stopping;

    IVsyncSource* m_VsyncSource;
    IFFmpegRenderer* m_VsyncRenderer;
    int m_MaxVideoFps;
    int m_DisplayFps;
    PVIDEO_STATS m_VideoStats;
    int m_RendererAttributes;
};
