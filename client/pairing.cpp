#include "pairing.h"

#include "http.h"
#include "identity.h"
#include "xml.h"

#include <cstdlib>
#include <cstring>

#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rand.h>
#include <openssl/x509.h>

namespace {

constexpr const char* kDeviceName = "roth";

std::string randomBytes(int length)
{
    std::string data((size_t)length, '\0');
    RAND_bytes(reinterpret_cast<unsigned char*>(&data[0]), length);
    return data;
}

std::string hexEncode(const std::string& data)
{
    static const char k_Hex[] = "0123456789abcdef";
    std::string result;
    result.reserve(data.size() * 2);
    for (unsigned char c : data) {
        result += k_Hex[c >> 4];
        result += k_Hex[c & 0xF];
    }
    return result;
}

std::string hexDecode(const std::string& hex)
{
    if (hex.size() % 2 != 0) {
        return {};
    }

    auto nibble = [](char c) -> int {
        if (c >= '0' && c <= '9') return c - '0';
        if (c >= 'a' && c <= 'f') return c - 'a' + 10;
        if (c >= 'A' && c <= 'F') return c - 'A' + 10;
        return -1;
    };

    std::string result;
    result.reserve(hex.size() / 2);
    for (size_t i = 0; i < hex.size(); i += 2) {
        int hi = nibble(hex[i]);
        int lo = nibble(hex[i + 1]);
        if (hi < 0 || lo < 0) {
            return {};
        }
        result.push_back((char)((hi << 4) | lo));
    }
    return result;
}

std::string digest(const std::string& data, const EVP_MD* md)
{
    unsigned char output[EVP_MAX_MD_SIZE];
    unsigned int length = 0;
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    if (ctx == nullptr) {
        return {};
    }
    EVP_DigestInit_ex(ctx, md, nullptr);
    EVP_DigestUpdate(ctx, data.data(), data.size());
    EVP_DigestFinal_ex(ctx, output, &length);
    EVP_MD_CTX_free(ctx);
    return std::string(reinterpret_cast<char*>(output), length);
}

// AES-128-ECB with padding disabled. `data` must be a multiple of 16 bytes.
std::string aesEcb(const std::string& data, const std::string& key, bool encrypt)
{
    if (data.empty()) {
        return {};
    }

    EVP_CIPHER_CTX* ctx = EVP_CIPHER_CTX_new();
    if (ctx == nullptr) {
        return {};
    }

    EVP_CipherInit_ex(ctx, EVP_aes_128_ecb(), nullptr,
                      reinterpret_cast<const unsigned char*>(key.data()), nullptr, encrypt ? 1 : 0);
    EVP_CIPHER_CTX_set_padding(ctx, 0);

    std::string output(data.size(), '\0');
    int outLen = 0;
    if (EVP_CipherUpdate(ctx, reinterpret_cast<unsigned char*>(&output[0]), &outLen,
                         reinterpret_cast<const unsigned char*>(data.data()), (int)data.size()) != 1 ||
        outLen != (int)data.size()) {
        EVP_CIPHER_CTX_free(ctx);
        return {};
    }
    EVP_CIPHER_CTX_free(ctx);
    return output;
}

std::string certSignatureFromPem(const std::string& certPem)
{
    BIO* bio = BIO_new_mem_buf(certPem.data(), (int)certPem.size());
    if (bio == nullptr) {
        return {};
    }
    X509* cert = PEM_read_bio_X509(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);
    if (cert == nullptr) {
        return {};
    }

    const ASN1_BIT_STRING* signature = nullptr;
    X509_get0_signature(&signature, nullptr, cert);
    std::string result;
    if (signature != nullptr) {
        result.assign(reinterpret_cast<const char*>(ASN1_STRING_get0_data(signature)),
                      ASN1_STRING_length(signature));
    }
    X509_free(cert);
    return result;
}

std::string signMessage(const std::string& message, const std::string& keyPem)
{
    BIO* bio = BIO_new_mem_buf(keyPem.data(), (int)keyPem.size());
    if (bio == nullptr) {
        return {};
    }
    EVP_PKEY* key = PEM_read_bio_PrivateKey(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);
    if (key == nullptr) {
        return {};
    }

    std::string signature;
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    if (ctx != nullptr && EVP_DigestSignInit(ctx, nullptr, EVP_sha256(), nullptr, key) == 1 &&
        EVP_DigestSignUpdate(ctx, message.data(), message.size()) == 1) {
        size_t signatureLength = 0;
        if (EVP_DigestSignFinal(ctx, nullptr, &signatureLength) == 1) {
            signature.resize(signatureLength);
            EVP_DigestSignFinal(ctx, reinterpret_cast<unsigned char*>(&signature[0]), &signatureLength);
            signature.resize(signatureLength);
        }
    }
    if (ctx != nullptr) {
        EVP_MD_CTX_free(ctx);
    }
    EVP_PKEY_free(key);
    return signature;
}

bool verifySignature(const std::string& data, const std::string& signature,
                     const std::string& serverCertPem)
{
    BIO* bio = BIO_new_mem_buf(serverCertPem.data(), (int)serverCertPem.size());
    if (bio == nullptr) {
        return false;
    }
    X509* cert = PEM_read_bio_X509(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);
    if (cert == nullptr) {
        return false;
    }

    EVP_PKEY* pubKey = X509_get_pubkey(cert);
    if (pubKey == nullptr) {
        X509_free(cert);
        return false;
    }

    bool verified = false;
    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    if (ctx != nullptr &&
        EVP_DigestVerifyInit(ctx, nullptr, EVP_sha256(), nullptr, pubKey) == 1 &&
        EVP_DigestVerifyUpdate(ctx, data.data(), data.size()) == 1 &&
        EVP_DigestVerifyFinal(ctx,
                              reinterpret_cast<const unsigned char*>(signature.data()),
                              signature.size()) > 0) {
        verified = true;
    }
    if (ctx != nullptr) {
        EVP_MD_CTX_free(ctx);
    }
    EVP_PKEY_free(pubKey);
    X509_free(cert);
    return verified;
}

bool checkResponseStatus(const std::string& xml, std::string& error)
{
    std::string statusCode = xmlAttribute(xml, "status_code");
    if (!statusCode.empty() && statusCode != "200") {
        std::string statusMessage = xmlAttribute(xml, "status_message");
        error = "Host returned error " + statusCode;
        if (!statusMessage.empty()) {
            error += ": " + statusMessage;
        }
        return false;
    }
    return true;
}

// Every request carries the client's unique ID and a fresh request UUID, like
// the Qt build's NvHTTP. The host rejects /pair without a uniqueid ("Missing
// uniqueid parameter") and uses it to match the pairing stages to each other.
std::string clientQuery(const std::string& uniqueId)
{
    return "uniqueid=" + uniqueId + "&uuid=" + hexEncode(randomBytes(16));
}

void unpair(const std::string& address, uint16_t httpPort, const std::string& uniqueId)
{
    std::string ignored;
    std::string response;
    httpGet(address, httpPort, "/unpair?" + clientQuery(uniqueId), response, ignored);
}

std::string pairQuery(const std::string& uniqueId, const std::string& extra)
{
    return "/pair?" + clientQuery(uniqueId) + "&devicename=" + std::string(kDeviceName) +
           "&updateState=1&" + extra;
}

} // namespace

PairState pairHost(const std::string& address, uint16_t httpPort, uint16_t httpsPort,
                   const std::string& serverAppVersion, const std::string& uniqueId,
                   const std::string& pin,
                   std::string& serverCertPem, std::string& error)
{
    // The host uses SHA-256 for the PIN hash on generation 7+ and SHA-1 before
    // that, mirroring the Qt build.
    int serverMajorVersion = atoi(serverAppVersion.c_str());
    bool useSha256 = serverMajorVersion >= 7;
    const EVP_MD* hashMd = useSha256 ? EVP_sha256() : EVP_sha1();
    size_t hashLength = useSha256 ? 32 : 20;

    std::string salt = randomBytes(16);
    std::string saltedPin = salt + pin;
    std::string aesKey = digest(saltedPin, hashMd);
    aesKey.resize(16);

    std::string clientCert = Identity::getCertificate();
    std::string clientKey = Identity::getPrivateKey();
    if (clientCert.empty() || clientKey.empty()) {
        error = "Unable to load the client identity";
        return PairState::Failed;
    }

    // Stage 1: exchange certificates. The client sends its certificate and
    // receives the host's plaintext certificate over HTTP. The host holds this
    // request open until the user enters the PIN on it, so it has no timeout
    // (as in the Qt build).
    std::string response;
    if (!httpGet(address, httpPort,
                 pairQuery(uniqueId, "phrase=getservercert&salt=" + hexEncode(salt) +
                           "&clientcert=" + hexEncode(clientCert)),
                 response, error, 0)) {
        return PairState::Failed;
    }
    if (!checkResponseStatus(response, error)) {
        return PairState::Failed;
    }
    if (xmlTag(response, "paired") != "1") {
        error = "Pairing failed at stage 1";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    std::string serverCertPemStage = hexDecode(xmlTag(response, "plaincert"));
    if (serverCertPemStage.empty()) {
        error = "The host is already in the middle of a pairing attempt";
        unpair(address, httpPort, uniqueId);
        return PairState::AlreadyInProgress;
    }

    std::string randomChallenge = randomBytes(16);
    std::string encryptedChallenge = aesEcb(randomChallenge, aesKey, true);
    if (encryptedChallenge.empty()) {
        error = "Failed to encrypt the client challenge";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    // Stage 2: send the encrypted challenge and derive the shared secret.
    response.clear();
    if (!httpGet(address, httpPort,
                 pairQuery(uniqueId, "clientchallenge=" + hexEncode(encryptedChallenge)),
                 response, error) ||
        !checkResponseStatus(response, error)) {
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }
    if (xmlTag(response, "paired") != "1") {
        error = "Pairing failed at stage 2";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    std::string challengeResponseData = aesEcb(hexDecode(xmlTag(response, "challengeresponse")), aesKey, false);
    if (challengeResponseData.size() < hashLength + 16) {
        error = "Invalid challenge response from the host";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    std::string serverResponse = challengeResponseData.substr(0, hashLength);
    std::string clientSecretData = randomBytes(16);

    std::string challengeResponse = challengeResponseData.substr(hashLength, 16);
    challengeResponse += certSignatureFromPem(clientCert);
    challengeResponse += clientSecretData;

    std::string paddedHash = digest(challengeResponse, hashMd);
    paddedHash.resize(32);
    std::string encryptedChallengeResponseHash = aesEcb(paddedHash, aesKey, true);
    if (encryptedChallengeResponseHash.empty()) {
        error = "Failed to encrypt the challenge response";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    // Stage 3: prove knowledge of the PIN and verify the host's signature.
    response.clear();
    if (!httpGet(address, httpPort,
                 pairQuery(uniqueId, "serverchallengeresp=" + hexEncode(encryptedChallengeResponseHash)),
                 response, error) ||
        !checkResponseStatus(response, error)) {
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }
    if (xmlTag(response, "paired") != "1") {
        error = "Pairing failed at stage 3";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    std::string pairingSecret = hexDecode(xmlTag(response, "pairingsecret"));
    if (pairingSecret.size() <= 16) {
        error = "Invalid pairing secret from the host";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    std::string serverSecret = pairingSecret.substr(0, 16);
    std::string serverSignature = pairingSecret.substr(16);
    if (!verifySignature(serverSecret, serverSignature, serverCertPemStage)) {
        error = "Man-in-the-middle detected: the host's signature did not verify";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    std::string expectedResponseData = randomChallenge;
    expectedResponseData += certSignatureFromPem(serverCertPemStage);
    expectedResponseData += serverSecret;
    if (digest(expectedResponseData, hashMd) != serverResponse) {
        error = "Incorrect PIN";
        unpair(address, httpPort, uniqueId);
        return PairState::PinWrong;
    }

    // Stage 4: send our signed pairing secret.
    std::string clientPairingSecret = clientSecretData + signMessage(clientSecretData, clientKey);
    response.clear();
    if (!httpGet(address, httpPort,
                 pairQuery(uniqueId, "clientpairingsecret=" + hexEncode(clientPairingSecret)),
                 response, error) ||
        !checkResponseStatus(response, error)) {
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }
    if (xmlTag(response, "paired") != "1") {
        error = "Pairing failed at stage 4";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    // Stage 5: confirm the pairing over mutual TLS using the host certificate
    // we just received.
    response.clear();
    if (!httpsGet(address, httpsPort, pairQuery(uniqueId, "phrase=pairchallenge"),
                  clientCert, clientKey, serverCertPemStage, response, error) ||
        !checkResponseStatus(response, error)) {
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }
    if (xmlTag(response, "paired") != "1") {
        error = "Pairing failed at stage 5";
        unpair(address, httpPort, uniqueId);
        return PairState::Failed;
    }

    serverCertPem = serverCertPemStage;
    return PairState::Paired;
}
