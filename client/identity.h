#pragma once

#include <string>

// The client's persistent pairing identity: a self-signed certificate, its
// private key, and a stable unique ID. These are the same values the Qt build
// stored under the "certificate"/"key"/"uniqueid" preference keys, so a
// machine that was already paired by the Qt build reuses its identity.
namespace Identity {

// Returns the client's PEM certificate, generating and persisting a new
// self-signed identity if one isn't already stored.
std::string getCertificate();

// Returns the client's PEM private key.
std::string getPrivateKey();

// Returns the stable client unique ID (base-16), generating and persisting one
// if it isn't already stored.
std::string getUniqueId();

} // namespace Identity
