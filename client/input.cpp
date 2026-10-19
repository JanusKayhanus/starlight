#include "input.h"

#include <Limelight.h>

namespace {

bool g_quitRequested = false;
bool g_relativeMouse = false;

short sdlKeyToVk(SDL_Keycode key, bool& extended)
{
    extended = false;

    if (key >= SDLK_a && key <= SDLK_z) {
        return (short)('A' + (key - SDLK_a));
    }
    if (key >= SDLK_0 && key <= SDLK_9) {
        return (short)('0' + (key - SDLK_0));
    }
    if (key >= SDLK_F1 && key <= SDLK_F12) {
        return (short)(0x70 + (key - SDLK_F1));
    }

    switch (key) {
    case SDLK_RETURN: return 0x0D;
    case SDLK_ESCAPE: return 0x1B;
    case SDLK_BACKSPACE: return 0x08;
    case SDLK_TAB: return 0x09;
    case SDLK_SPACE: return 0x20;
    case SDLK_MINUS: return 0xBD;
    case SDLK_EQUALS: return 0xBB;
    case SDLK_LEFTBRACKET: return 0xDB;
    case SDLK_RIGHTBRACKET: return 0xDD;
    case SDLK_BACKSLASH: return 0xDC;
    case SDLK_SEMICOLON: return 0xBA;
    case SDLK_QUOTE: return 0xDE;
    case SDLK_BACKQUOTE: return 0xC0;
    case SDLK_COMMA: return 0xBC;
    case SDLK_PERIOD: return 0xBE;
    case SDLK_SLASH: return 0xBF;
    case SDLK_CAPSLOCK: return 0x14;
    case SDLK_PRINTSCREEN: return 0x2C;
    case SDLK_SCROLLLOCK: return 0x91;
    case SDLK_PAUSE: return 0x13;
    case SDLK_INSERT: extended = true; return 0x2D;
    case SDLK_HOME: extended = true; return 0x24;
    case SDLK_PAGEUP: extended = true; return 0x21;
    case SDLK_DELETE: extended = true; return 0x2E;
    case SDLK_END: extended = true; return 0x23;
    case SDLK_PAGEDOWN: extended = true; return 0x22;
    case SDLK_RIGHT: extended = true; return 0x27;
    case SDLK_LEFT: extended = true; return 0x25;
    case SDLK_DOWN: extended = true; return 0x28;
    case SDLK_UP: extended = true; return 0x26;
    case SDLK_NUMLOCKCLEAR: return 0x90;
    case SDLK_KP_DIVIDE: extended = true; return 0x6F;
    case SDLK_KP_MULTIPLY: return 0x6A;
    case SDLK_KP_MINUS: return 0x6D;
    case SDLK_KP_PLUS: return 0x6B;
    case SDLK_KP_ENTER: extended = true; return 0x0D;
    case SDLK_KP_1: return 0x61;
    case SDLK_KP_2: return 0x62;
    case SDLK_KP_3: return 0x63;
    case SDLK_KP_4: return 0x64;
    case SDLK_KP_5: return 0x65;
    case SDLK_KP_6: return 0x66;
    case SDLK_KP_7: return 0x67;
    case SDLK_KP_8: return 0x68;
    case SDLK_KP_9: return 0x69;
    case SDLK_KP_0: return 0x60;
    case SDLK_KP_PERIOD: return 0x6E;
    case SDLK_LCTRL: return 0xA2;
    case SDLK_LSHIFT: return 0xA0;
    case SDLK_LALT: return 0xA4;
    case SDLK_LGUI: return 0x5B;
    case SDLK_RCTRL: extended = true; return 0xA3;
    case SDLK_RSHIFT: return 0xA1;
    case SDLK_RALT: extended = true; return 0xA5;
    case SDLK_RGUI: extended = true; return 0x5C;
    default: return 0;
    }
}

char currentModifiers()
{
    SDL_Keymod mod = SDL_GetModState();
    char modifiers = 0;
    if (mod & KMOD_SHIFT) modifiers |= MODIFIER_SHIFT;
    if (mod & KMOD_CTRL) modifiers |= MODIFIER_CTRL;
    if (mod & KMOD_ALT) modifiers |= MODIFIER_ALT;
    if (mod & KMOD_GUI) modifiers |= MODIFIER_META;
    return modifiers;
}

void sendKey(SDL_KeyboardEvent* event, bool down)
{
    bool extended = false;
    short vk = sdlKeyToVk(event->keysym.sym, extended);
    if (vk == 0) {
        return;
    }

    char modifiers = currentModifiers();
    if (extended) {
        modifiers |= MODIFIER_EXTENDED;
    }

    LiSendKeyboardEvent(vk, down ? KEY_ACTION_DOWN : KEY_ACTION_UP, modifiers);
}

} // namespace

bool handleInputEvent(const SDL_Event& event)
{
    switch (event.type) {
    case SDL_QUIT:
        g_quitRequested = true;
        break;

    case SDL_KEYDOWN:
        // Cmd+Q and Ctrl+Alt+Shift+Q exit the stream.
        if ((event.key.keysym.sym == SDLK_q) &&
            ((event.key.keysym.mod & KMOD_GUI) ||
             ((event.key.keysym.mod & KMOD_CTRL) &&
              (event.key.keysym.mod & KMOD_ALT) &&
              (event.key.keysym.mod & KMOD_SHIFT)))) {
            g_quitRequested = true;
            break;
        }
        sendKey((SDL_KeyboardEvent*)&event.key, true);
        break;

    case SDL_KEYUP:
        sendKey((SDL_KeyboardEvent*)&event.key, false);
        break;

    case SDL_MOUSEMOTION:
        if (g_relativeMouse) {
            LiSendMouseMoveEvent((short)event.motion.xrel, (short)event.motion.yrel);
        }
        break;

    case SDL_MOUSEBUTTONDOWN:
    case SDL_MOUSEBUTTONUP: {
        int button;
        switch (event.button.button) {
        case SDL_BUTTON_LEFT: button = BUTTON_LEFT; break;
        case SDL_BUTTON_MIDDLE: button = BUTTON_MIDDLE; break;
        case SDL_BUTTON_RIGHT: button = BUTTON_RIGHT; break;
        case SDL_BUTTON_X1: button = BUTTON_X1; break;
        case SDL_BUTTON_X2: button = BUTTON_X2; break;
        default: return false;
        }
        LiSendMouseButtonEvent(event.type == SDL_MOUSEBUTTONDOWN ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
                               button);
        break;
    }

    case SDL_MOUSEWHEEL:
        if (event.wheel.y != 0) {
            LiSendHighResScrollEvent((short)(event.wheel.y * 120));
        }
        if (event.wheel.x != 0) {
            LiSendHighResHScrollEvent((short)(event.wheel.x * 120));
        }
        break;

    default:
        break;
    }

    return g_quitRequested;
}

void enableRelativeMouse()
{
    g_relativeMouse = SDL_SetRelativeMouseMode(SDL_TRUE) == 0;
}
