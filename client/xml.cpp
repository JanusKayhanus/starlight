#include "xml.h"

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
