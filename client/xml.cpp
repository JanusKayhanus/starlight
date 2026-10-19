#include "xml.h"

#include <cstdlib>
#include <cstring>

std::string xmlTag(const std::string& xml, const char* tag)
{
    std::string open = std::string("<") + tag + ">";
    std::string close = std::string("</") + tag + ">";
    size_t start = xml.find(open);
    if (start == std::string::npos) {
        return {};
    }
    start += open.size();
    size_t end = xml.find(close, start);
    if (end == std::string::npos) {
        return {};
    }
    return xml.substr(start, end - start);
}

std::string xmlAttribute(const std::string& xml, const char* name)
{
    std::string needle = std::string(name) + "=\"";
    size_t start = xml.find(needle);
    if (start == std::string::npos) {
        return {};
    }
    start += needle.size();
    size_t end = xml.find('"', start);
    return end == std::string::npos ? std::string() : xml.substr(start, end - start);
}

std::vector<std::string> xmlTags(const std::string& xml, const char* tag)
{
    std::vector<std::string> result;
    std::string open = std::string("<") + tag + ">";
    std::string close = std::string("</") + tag + ">";

    size_t pos = 0;
    for (;;) {
        size_t start = xml.find(open, pos);
        if (start == std::string::npos) {
            break;
        }
        start += open.size();
        size_t end = xml.find(close, start);
        if (end == std::string::npos) {
            break;
        }
        result.push_back(xml.substr(start, end - start));
        pos = end + close.size();
    }

    return result;
}

namespace {

void appendUtf8(std::string& out, unsigned long codePoint)
{
    if (codePoint < 0x80) {
        out += (char)codePoint;
    }
    else if (codePoint < 0x800) {
        out += (char)(0xC0 | (codePoint >> 6));
        out += (char)(0x80 | (codePoint & 0x3F));
    }
    else if (codePoint < 0x10000) {
        out += (char)(0xE0 | (codePoint >> 12));
        out += (char)(0x80 | ((codePoint >> 6) & 0x3F));
        out += (char)(0x80 | (codePoint & 0x3F));
    }
    else if (codePoint < 0x110000) {
        out += (char)(0xF0 | (codePoint >> 18));
        out += (char)(0x80 | ((codePoint >> 12) & 0x3F));
        out += (char)(0x80 | ((codePoint >> 6) & 0x3F));
        out += (char)(0x80 | (codePoint & 0x3F));
    }
}

} // namespace

std::string xmlUnescape(const std::string& text)
{
    static const struct {
        const char* entity;
        char value;
    } k_Entities[] = {
        { "&amp;", '&' }, { "&lt;", '<' }, { "&gt;", '>' }, { "&quot;", '"' }, { "&apos;", '\'' },
    };

    std::string out;
    out.reserve(text.size());
    for (size_t i = 0; i < text.size();) {
        if (text[i] != '&') {
            out += text[i++];
            continue;
        }

        bool decoded = false;
        for (const auto& entry : k_Entities) {
            size_t length = strlen(entry.entity);
            if (text.compare(i, length, entry.entity) == 0) {
                out += entry.value;
                i += length;
                decoded = true;
                break;
            }
        }

        size_t semicolon = text.find(';', i);
        if (!decoded && text.compare(i, 2, "&#") == 0 && semicolon != std::string::npos) {
            bool hex = i + 2 < text.size() && (text[i + 2] == 'x' || text[i + 2] == 'X');
            std::string digits = text.substr(i + (hex ? 3 : 2), semicolon - i - (hex ? 3 : 2));
            char* end = nullptr;
            unsigned long codePoint = strtoul(digits.c_str(), &end, hex ? 16 : 10);
            if (!digits.empty() && *end == '\0') {
                appendUtf8(out, codePoint);
                i = semicolon + 1;
                decoded = true;
            }
        }

        if (!decoded) {
            out += text[i++];
        }
    }
    return out;
}
