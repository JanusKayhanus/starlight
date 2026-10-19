#pragma once

#include <string>
#include <vector>

// Minimal helpers for the small XML documents exchanged with the host.
// Moonlight's protocol responses are flat and well-formed, so a full XML
// parser is unnecessary here.
std::string xmlTag(const std::string& xml, const char* tag);
std::string xmlAttribute(const std::string& xml, const char* name);
std::vector<std::string> xmlTags(const std::string& xml, const char* tag);

// Decodes the predefined entities (&amp; &lt; &gt; &quot; &apos;) and
// numeric character references in element text.
std::string xmlUnescape(const std::string& text);
