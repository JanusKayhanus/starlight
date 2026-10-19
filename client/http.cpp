#include "http.h"

#include <arpa/inet.h>
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <openssl/err.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>

#include <algorithm>
#include <cerrno>
#include <chrono>

#include <SDL.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

namespace {

// How often a wait wakes up to check for cancellation.
constexpr int kCancelPollIntervalMs = 100;

// Waits until `fd` is ready for `events`. `timeoutSeconds` bounds the wait;
// 0 waits indefinitely. Returns false (with `error` set) on timeout or
// cancellation. An error condition on the socket counts as ready, so the
// caller's next operation reports it.
bool waitForSocket(int fd, short events, int timeoutSeconds,
                   const CancellationToken* cancel, std::string& error)
{
    using Clock = std::chrono::steady_clock;
    const auto deadline = Clock::now() + std::chrono::seconds(timeoutSeconds);

    for (;;) {
        if (isCancelled(cancel)) {
            error = kCancelledError;
            return false;
        }

        int waitMs = kCancelPollIntervalMs;
        if (timeoutSeconds > 0) {
            auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(deadline - Clock::now()).count();
            if (remaining <= 0) {
                error = "The request timed out";
                return false;
            }
            waitMs = (int)std::min<long long>(waitMs, remaining);
        }

        struct pollfd pfd = {};
        pfd.fd = fd;
        pfd.events = events;
        int ret = poll(&pfd, 1, waitMs);
        if (ret > 0) {
            return true;
        }
        if (ret < 0 && errno != EINTR) {
            error = std::string("poll failed: ") + strerror(errno);
            return false;
        }
    }
}

// Connects a non-blocking socket, so that every later wait can be cancelled.
int connectTcp(const std::string& host, uint16_t port, int timeoutSeconds,
               const CancellationToken* cancel, std::string& error)
{
    struct addrinfo hints = {};
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;

    struct addrinfo* result = nullptr;
    std::string portString = std::to_string(port);
    int err = getaddrinfo(host.c_str(), portString.c_str(), &hints, &result);
    if (err != 0) {
        error = std::string("getaddrinfo failed: ") + gai_strerror(err);
        return -1;
    }

    int fd = -1;
    for (struct addrinfo* ai = result; ai != nullptr && !isCancelled(cancel); ai = ai->ai_next) {
        fd = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (fd < 0) {
            continue;
        }

        // Report a closed connection as an error from send() instead of
        // killing the process with SIGPIPE.
        int noSigPipe = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, sizeof(noSigPipe));
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK);

        int connectError = 0;
        if (connect(fd, ai->ai_addr, ai->ai_addrlen) != 0) {
            connectError = errno;
            if (connectError == EINPROGRESS) {
                std::string waitError;
                if (waitForSocket(fd, POLLOUT, timeoutSeconds, cancel, waitError)) {
                    socklen_t length = sizeof(connectError);
                    if (getsockopt(fd, SOL_SOCKET, SO_ERROR, &connectError, &length) != 0) {
                        connectError = errno;
                    }
                }
                else {
                    connectError = ETIMEDOUT;
                }
            }
        }

        if (connectError == 0) {
            break;
        }

        if (!isCancelled(cancel)) {
            SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "connect to %s:%s failed: %s",
                         host.c_str(), portString.c_str(), strerror(connectError));
        }
        close(fd);
        fd = -1;
    }

    freeaddrinfo(result);

    if (fd < 0) {
        error = isCancelled(cancel) ? kCancelledError : "Unable to connect to " + host + ":" + portString;
    }

    return fd;
}

bool sendAll(int fd, const std::string& data, int timeoutSeconds,
             const CancellationToken* cancel, std::string& error)
{
    size_t sent = 0;
    while (sent < data.size()) {
        ssize_t ret = send(fd, data.data() + sent, data.size() - sent, 0);
        if (ret > 0) {
            sent += (size_t)ret;
        }
        else if (ret < 0 && (errno == EAGAIN || errno == EINTR)) {
            if (!waitForSocket(fd, POLLOUT, timeoutSeconds, cancel, error)) {
                return false;
            }
        }
        else {
            error = std::string("send failed: ") + strerror(errno);
            return false;
        }
    }
    return true;
}

std::string buildRequest(const std::string& host, uint16_t port, const std::string& path)
{
    std::string request;
    request += "GET " + path + " HTTP/1.1\r\n";
    request += "Host: " + host + ":" + std::to_string(port) + "\r\n";
    request += "User-Agent: Moonlight-QtFree\r\n";
    request += "Accept: */*\r\n";
    request += "Connection: close\r\n\r\n";
    return request;
}

bool decodeChunked(const std::string& body, std::string& decoded)
{
    size_t pos = 0;
    while (pos < body.size()) {
        size_t lineEnd = body.find("\r\n", pos);
        if (lineEnd == std::string::npos) {
            return false;
        }

        unsigned long chunkSize = strtoul(body.substr(pos, lineEnd - pos).c_str(), nullptr, 16);
        pos = lineEnd + 2;

        if (chunkSize == 0) {
            return true;
        }

        if (pos + chunkSize > body.size()) {
            return false;
        }

        decoded.append(body, pos, chunkSize);
        pos += chunkSize;
        if (body.compare(pos, 2, "\r\n") != 0) {
            return false;
        }
        pos += 2;
    }
    return true;
}

bool parseHttpResponse(const std::string& raw, std::string& body, std::string& error,
                       int* httpStatusCode = nullptr)
{
    size_t headerEnd = raw.find("\r\n\r\n");
    if (headerEnd == std::string::npos) {
        error = "Malformed HTTP response";
        return false;
    }

    std::string headers = raw.substr(0, headerEnd);
    body = raw.substr(headerEnd + 4);

    int statusCode = 0;
    if (sscanf(headers.c_str(), "HTTP/%*s %d", &statusCode) != 1) {
        error = "Malformed HTTP status line";
        return false;
    }

    if (httpStatusCode != nullptr) {
        *httpStatusCode = statusCode;
    }

    if (statusCode != 200) {
        error = "HTTP request failed with status " + std::to_string(statusCode);
        return false;
    }

    if (headers.find("Transfer-Encoding: chunked") != std::string::npos ||
        headers.find("Transfer-Encoding: Chunked") != std::string::npos) {
        std::string decoded;
        if (!decodeChunked(body, decoded)) {
            error = "Malformed chunked HTTP response";
            return false;
        }
        body.swap(decoded);
    }

    return true;
}

SSL_CTX* createSslContext(const std::string& clientCertPem,
                          const std::string& clientKeyPem,
                          std::string& error)
{
    SSL_CTX* ctx = SSL_CTX_new(TLS_client_method());
    if (ctx == nullptr) {
        error = "SSL_CTX_new failed";
        return nullptr;
    }

    SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);
    SSL_CTX_set_security_level(ctx, 0);
    SSL_CTX_set_verify(ctx, SSL_VERIFY_NONE, nullptr);

    BIO* certBio = BIO_new_mem_buf(clientCertPem.data(), (int)clientCertPem.size());
    X509* clientCert = certBio ? PEM_read_bio_X509(certBio, nullptr, nullptr, nullptr) : nullptr;
    if (clientCert == nullptr) {
        error = "Unable to parse the client certificate";
        SSL_CTX_free(ctx);
        BIO_free(certBio);
        return nullptr;
    }
    SSL_CTX_use_certificate(ctx, clientCert);
    X509_free(clientCert);
    BIO_free(certBio);

    BIO* keyBio = BIO_new_mem_buf(clientKeyPem.data(), (int)clientKeyPem.size());
    EVP_PKEY* clientKey = keyBio ? PEM_read_bio_PrivateKey(keyBio, nullptr, nullptr, nullptr) : nullptr;
    if (clientKey == nullptr) {
        error = "Unable to parse the client private key";
        SSL_CTX_free(ctx);
        BIO_free(keyBio);
        return nullptr;
    }
    SSL_CTX_use_PrivateKey(ctx, clientKey);
    EVP_PKEY_free(clientKey);
    BIO_free(keyBio);

    if (!SSL_CTX_check_private_key(ctx)) {
        error = "Client certificate and private key do not match";
        SSL_CTX_free(ctx);
        return nullptr;
    }

    return ctx;
}

bool verifyPinnedServerCert(SSL* ssl, const std::string& serverCertPem, std::string& error)
{
    // We authenticate the host by pinned certificate rather than the system
    // trust store (Moonlight hosts use self-signed certificates), so a missing
    // pin must be treated as a failure rather than silently skipping
    // verification.
    if (serverCertPem.empty()) {
        error = "No pinned server certificate is available";
        return false;
    }

    X509* peer = SSL_get1_peer_certificate(ssl);
    if (peer == nullptr) {
        error = "Server did not present a certificate";
        return false;
    }

    BIO* bio = BIO_new_mem_buf(serverCertPem.data(), (int)serverCertPem.size());
    X509* expected = bio ? PEM_read_bio_X509(bio, nullptr, nullptr, nullptr) : nullptr;
    BIO_free(bio);

    if (expected == nullptr) {
        X509_free(peer);
        error = "Unable to parse the pinned server certificate";
        return false;
    }

    bool ok = X509_cmp(peer, expected) == 0;
    X509_free(expected);
    X509_free(peer);

    if (!ok) {
        error = "Server certificate does not match the pinned certificate";
    }
    return ok;
}

bool readAll(int fd, std::string& response, int timeoutSeconds,
             const CancellationToken* cancel, std::string& error)
{
    char buffer[8192];
    for (;;) {
        ssize_t ret = recv(fd, buffer, sizeof(buffer), 0);
        if (ret > 0) {
            response.append(buffer, (size_t)ret);
        }
        else if (ret == 0) {
            return true;
        }
        else if (errno == EAGAIN || errno == EINTR) {
            if (!waitForSocket(fd, POLLIN, timeoutSeconds, cancel, error)) {
                return false;
            }
        }
        else {
            error = std::string("recv failed: ") + strerror(errno);
            return false;
        }
    }
}

// Runs one OpenSSL call on a non-blocking socket, waiting for the socket
// whenever OpenSSL asks to. Returns the call's positive result, 0 on a clean
// TLS close, or -1 on failure (with `error` set).
template <typename Operation>
int runSsl(SSL* ssl, int fd, int timeoutSeconds, const CancellationToken* cancel,
           const char* what, std::string& error, Operation operation)
{
    for (;;) {
        int ret = operation();
        if (ret > 0) {
            return ret;
        }

        switch (SSL_get_error(ssl, ret)) {
        case SSL_ERROR_WANT_READ:
            if (!waitForSocket(fd, POLLIN, timeoutSeconds, cancel, error)) {
                return -1;
            }
            break;
        case SSL_ERROR_WANT_WRITE:
            if (!waitForSocket(fd, POLLOUT, timeoutSeconds, cancel, error)) {
                return -1;
            }
            break;
        case SSL_ERROR_ZERO_RETURN:
            return 0;
        default:
            error = what;
            return -1;
        }
    }
}

bool readAllSsl(SSL* ssl, int fd, std::string& response, int timeoutSeconds,
                const CancellationToken* cancel, std::string& error)
{
    char buffer[8192];
    for (;;) {
        int ret = runSsl(ssl, fd, timeoutSeconds, cancel, "SSL_read failed", error, [&] {
            return SSL_read(ssl, buffer, sizeof(buffer));
        });
        if (ret > 0) {
            response.append(buffer, (size_t)ret);
        }
        else {
            return ret == 0;
        }
    }
}

} // namespace

bool httpGet(const std::string& host, uint16_t port, const std::string& path,
             std::string& response, std::string& error, int timeoutSeconds,
             const CancellationToken* cancel)
{
    int fd = connectTcp(host, port, timeoutSeconds, cancel, error);
    if (fd < 0) {
        return false;
    }

    std::string raw;
    bool ok = sendAll(fd, buildRequest(host, port, path), timeoutSeconds, cancel, error) &&
              readAll(fd, raw, timeoutSeconds, cancel, error) &&
              parseHttpResponse(raw, response, error);

    close(fd);
    return ok;
}

bool httpsGet(const std::string& host, uint16_t port, const std::string& path,
              const std::string& clientCertPem, const std::string& clientKeyPem,
              const std::string& serverCertPem,
              std::string& response, std::string& error,
              int timeoutSeconds, int* httpStatusCode,
              const CancellationToken* cancel)
{
    if (httpStatusCode != nullptr) {
        *httpStatusCode = 0;
    }

    SSL_CTX* ctx = createSslContext(clientCertPem, clientKeyPem, error);
    if (ctx == nullptr) {
        return false;
    }

    int fd = connectTcp(host, port, timeoutSeconds, cancel, error);
    if (fd < 0) {
        SSL_CTX_free(ctx);
        return false;
    }

    bool ok = false;
    SSL* ssl = SSL_new(ctx);
    if (ssl == nullptr) {
        error = "SSL_new failed";
    }
    else {
        SSL_set_fd(ssl, fd);
        SSL_set_tlsext_host_name(ssl, host.c_str());

        std::string request = buildRequest(host, port, path);
        std::string raw;
        if (runSsl(ssl, fd, timeoutSeconds, cancel, "TLS handshake failed", error,
                   [&] { return SSL_connect(ssl); }) <= 0) {
            // error is set
        }
        else if (!verifyPinnedServerCert(ssl, serverCertPem, error)) {
        }
        else if (runSsl(ssl, fd, timeoutSeconds, cancel, "Failed to send HTTPS request", error,
                        [&] { return SSL_write(ssl, request.data(), (int)request.size()); }) != (int)request.size()) {
            if (error.empty()) {
                error = "Failed to send HTTPS request";
            }
        }
        else if (readAllSsl(ssl, fd, raw, timeoutSeconds, cancel, error)) {
            ok = parseHttpResponse(raw, response, error, httpStatusCode);
        }

        // Best effort: don't wait for the host's close_notify.
        SSL_shutdown(ssl);
        SSL_free(ssl);
    }

    close(fd);
    SSL_CTX_free(ctx);
    return ok;
}
