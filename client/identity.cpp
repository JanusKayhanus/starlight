#include "identity.h"

#include "cfprefs.h"

#include <cstdio>
#include <cstdlib>

#include <openssl/bio.h>
#include <openssl/evp.h>
#include <openssl/pem.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/x509.h>

namespace {

constexpr const char* kSerUniqueId = "uniqueid";
constexpr const char* kSerCert = "certificate";
constexpr const char* kSerKey = "key";

std::string bioToPem(BIO* bio)
{
    BUF_MEM* mem = nullptr;
    BIO_get_mem_ptr(bio, &mem);
    if (mem == nullptr) {
        return {};
    }
    return std::string(mem->data, mem->length);
}

bool isValidPemKey(const std::string& keyPem)
{
    BIO* bio = BIO_new_mem_buf(keyPem.data(), (int)keyPem.size());
    if (bio == nullptr) {
        return false;
    }
    EVP_PKEY* key = PEM_read_bio_PrivateKey(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);
    if (key == nullptr) {
        return false;
    }
    EVP_PKEY_free(key);
    return true;
}

bool isValidPemCert(const std::string& certPem)
{
    BIO* bio = BIO_new_mem_buf(certPem.data(), (int)certPem.size());
    if (bio == nullptr) {
        return false;
    }
    X509* cert = PEM_read_bio_X509(bio, nullptr, nullptr, nullptr);
    BIO_free(bio);
    if (cert == nullptr) {
        return false;
    }
    X509_free(cert);
    return true;
}

bool createCredentials(std::string& certPem, std::string& keyPem)
{
    X509* cert = X509_new();
    if (cert == nullptr) {
        return false;
    }

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
    EVP_PKEY* pk = EVP_RSA_gen(2048);
#else
    EVP_PKEY_CTX* ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, nullptr);
    EVP_PKEY* pk = nullptr;
    if (ctx != nullptr) {
        EVP_PKEY_keygen_init(ctx);
        EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, 2048);
        EVP_PKEY_keygen(ctx, &pk);
        EVP_PKEY_CTX_free(ctx);
    }
#endif
    if (pk == nullptr) {
        X509_free(cert);
        return false;
    }

    X509_set_version(cert, 2);
    ASN1_INTEGER_set(X509_get_serialNumber(cert), 0);
    X509_gmtime_adj(X509_getm_notBefore(cert), 0);
    X509_gmtime_adj(X509_getm_notAfter(cert), 60 * 60 * 24 * 365 * 20); // 20 years
    X509_set_pubkey(cert, pk);

    X509_NAME* name = X509_NAME_new();
    if (name == nullptr) {
        X509_free(cert);
        EVP_PKEY_free(pk);
        return false;
    }
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC,
                               reinterpret_cast<unsigned char*>(const_cast<char*>("NVIDIA GameStream Client")),
                               -1, -1, 0);
    X509_set_subject_name(cert, name);
    X509_set_issuer_name(cert, name);
    X509_NAME_free(name);

    X509_sign(cert, pk, EVP_sha256());

    BIO* keyBio = BIO_new(BIO_s_mem());
    BIO* certBio = BIO_new(BIO_s_mem());
    if (keyBio == nullptr || certBio == nullptr) {
        X509_free(cert);
        EVP_PKEY_free(pk);
        BIO_free(keyBio);
        BIO_free(certBio);
        return false;
    }

    PEM_write_bio_PrivateKey(keyBio, pk, nullptr, nullptr, 0, nullptr, nullptr);
    PEM_write_bio_X509(certBio, cert);

    keyPem = bioToPem(keyBio);
    certPem = bioToPem(certBio);

    X509_free(cert);
    EVP_PKEY_free(pk);
    BIO_free(keyBio);
    BIO_free(certBio);

    return !certPem.empty() && !keyPem.empty() && isValidPemCert(certPem) && isValidPemKey(keyPem);
}

std::string loadCertificate()
{
    std::string certPem = CfPrefs::copyData(kSerCert);
    if (isValidPemCert(certPem)) {
        return certPem;
    }

    std::string generatedCert;
    std::string generatedKey;
    if (!createCredentials(generatedCert, generatedKey)) {
        fprintf(stderr, "Identity: failed to generate a client certificate\n");
        return {};
    }

    CfPrefs::setData(kSerCert, generatedCert);
    CfPrefs::setData(kSerKey, generatedKey);
    fprintf(stderr, "Identity: wrote new client credentials to preferences\n");
    return generatedCert;
}

std::string loadPrivateKey()
{
    std::string keyPem = CfPrefs::copyData(kSerKey);
    if (isValidPemKey(keyPem)) {
        return keyPem;
    }

    // Regenerate both so the certificate and key always match.
    std::string generatedCert;
    std::string generatedKey;
    if (!createCredentials(generatedCert, generatedKey)) {
        fprintf(stderr, "Identity: failed to generate a client private key\n");
        return {};
    }

    CfPrefs::setData(kSerCert, generatedCert);
    CfPrefs::setData(kSerKey, generatedKey);
    return generatedKey;
}

} // namespace

namespace Identity {

std::string getCertificate()
{
    static std::string cached = loadCertificate();
    return cached;
}

std::string getPrivateKey()
{
    static std::string cached = loadPrivateKey();
    return cached;
}

std::string getUniqueId()
{
    static std::string cached = [] {
        std::string uniqueId = CfPrefs::copyString(kSerUniqueId);
        if (!uniqueId.empty()) {
            return uniqueId;
        }

        unsigned char bytes[8];
        RAND_bytes(bytes, sizeof(bytes));

        char buffer[17];
        for (int i = 0; i < 8; i++) {
            snprintf(&buffer[i * 2], 3, "%02x", bytes[i]);
        }

        uniqueId = std::string(buffer, 16);
        CfPrefs::setString(kSerUniqueId, uniqueId);
        fprintf(stderr, "Identity: generated new unique ID %s\n", uniqueId.c_str());
        return uniqueId;
    }();
    return cached;
}

} // namespace Identity
