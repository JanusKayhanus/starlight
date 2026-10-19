#import "StarlightCore.h"

#include "cancellation.h"
#include "hostrequests.h"
#include "identity.h"
#include "pairing.h"
#include "serverinfo.h"
#include "settings.h"
#include "wol.h"

#include <string>
#include <vector>

NSErrorDomain const SLCoreErrorDomain = @"com.moonlight-stream.Starlight.core";

@interface SLCancellation ()
- (const CancellationToken*)token;
@end

@implementation SLCancellation {
    CancellationToken _token;
}

- (void)cancel
{
    _token.cancel();
}

- (const CancellationToken*)token
{
    return &_token;
}

@end

@implementation SLApp

- (instancetype)initWithApp:(const HostApp&)app
{
    if ((self = [super init])) {
        _appID = app.id;
        _name = [NSString stringWithUTF8String:app.name.c_str()] ?: @"";
        _hdrSupported = app.hdrSupported;
        _hidden = app.hidden;
    }
    return self;
}

@end

@implementation SLHost

- (instancetype)initWithHost:(const HostConfig&)host polled:(BOOL)polled
{
    if ((self = [super init])) {
        NSString* uuid = [NSString stringWithUTF8String:host.uuid.c_str()] ?: @"";
        _address = [NSString stringWithUTF8String:host.address.c_str()] ?: @"";
        _identifier = uuid.length > 0 ? uuid : _address;
        _name = [NSString stringWithUTF8String:host.name.c_str()] ?: _address;
        if (_name.length == 0) {
            _name = _address;
        }
        _canWake = host.macAddress.size() == 6;
        _paired = polled && host.isPaired;
        _runningAppID = polled ? host.currentGameId : 0;

        NSMutableArray<SLApp*>* apps = [NSMutableArray array];
        for (const HostApp& app : host.apps) {
            [apps addObject:[[SLApp alloc] initWithApp:app]];
        }
        _apps = [apps copy];
    }
    return self;
}

@end

namespace {

std::string toStd(NSString* string)
{
    return string.UTF8String != nullptr ? std::string(string.UTF8String) : std::string();
}

const CancellationToken* tokenOf(SLCancellation* cancellation)
{
    return cancellation != nil ? [cancellation token] : nullptr;
}

// Reports `message` through `error`, as a cancellation if `cancellation` was
// cancelled. Always returns NO, for `return fail(...)`.
BOOL fail(NSError** error, const std::string& message, SLCancellation* cancellation = nil)
{
    if (error != nullptr) {
        bool cancelled = isCancelled(tokenOf(cancellation));
        NSString* description = [NSString stringWithUTF8String:message.c_str()] ?: @"Unknown error";
        *error = [NSError errorWithDomain:SLCoreErrorDomain
                                     code:cancelled ? SLCoreErrorCancelled : SLCoreErrorFailed
                                 userInfo:@{ NSLocalizedDescriptionKey: description }];
    }
    return NO;
}

// The client identity, created on first use as the CLI's pair command does.
ClientConfig currentClient()
{
    ClientConfig client;
    client.uniqueId = Identity::getUniqueId();
    client.certPem = Identity::getCertificate();
    client.keyPem = Identity::getPrivateKey();
    return client;
}

bool findSavedHost(NSString* identifier, HostConfig& host)
{
    std::string error;
    return selectSavedHost(loadSavedHosts(), toStd(identifier), host, error);
}

} // namespace

@implementation SLCore

+ (NSArray<SLHost*>*)savedHosts
{
    NSMutableArray<SLHost*>* hosts = [NSMutableArray array];
    for (const HostConfig& host : loadSavedHosts()) {
        [hosts addObject:[[SLHost alloc] initWithHost:host polled:NO]];
    }
    return hosts;
}

+ (SLHost*)fetchStatusOfHost:(NSString*)identifier
                     address:(NSString*)address
                cancellation:(SLCancellation*)cancellation
                       error:(NSError**)error
{
    HostConfig host;
    bool saved = findSavedHost(identifier, host);
    if (!saved) {
        host.address = toStd(address);
    }

    std::string message;
    if (!fetchServerInfo(host, currentClient(), message, tokenOf(cancellation))) {
        fail(error, message, cancellation);
        return nil;
    }
    if (saved) {
        // Keeps the MAC address and name current for Wake-on-LAN.
        saveHostDetails(host);
    }
    return [[SLHost alloc] initWithHost:host polled:YES];
}

+ (NSArray<SLApp*>*)fetchAppsOfHost:(NSString*)identifier
                       cancellation:(SLCancellation*)cancellation
                              error:(NSError**)error
{
    HostConfig host;
    if (!findSavedHost(identifier, host)) {
        fail(error, "This computer isn't paired");
        return nil;
    }

    // serverinfo first, for the host's current HTTPS port.
    ClientConfig client = currentClient();
    std::string message;
    if (!fetchServerInfo(host, client, message, tokenOf(cancellation)) ||
            !fetchAppList(host, client, message, tokenOf(cancellation))) {
        fail(error, message, cancellation);
        return nil;
    }
    saveHostDetails(host);
    return [[SLHost alloc] initWithHost:host polled:YES].apps;
}

+ (BOOL)wakeHost:(NSString*)identifier error:(NSError**)error
{
    HostConfig host;
    if (!findSavedHost(identifier, host)) {
        return fail(error, "This computer isn't saved");
    }

    std::string message;
    return sendWakeOnLan(host, message) ? YES : fail(error, message);
}

+ (SLHost*)resolveAddress:(NSString*)address
             cancellation:(SLCancellation*)cancellation
                    error:(NSError**)error
{
    std::string trimmed = toStd([address stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]);
    if (trimmed.empty()) {
        fail(error, "Enter a name or address");
        return nil;
    }
    return [self fetchStatusOfHost:@(trimmed.c_str()) address:@(trimmed.c_str())
                      cancellation:cancellation error:error];
}

+ (SLHost*)pairWithHostAtAddress:(NSString*)address
                             pin:(NSString*)pin
                    cancellation:(SLCancellation*)cancellation
                           error:(NSError**)error
{
    const CancellationToken* token = tokenOf(cancellation);
    ClientConfig client = currentClient();
    if (client.certPem.empty() || client.keyPem.empty()) {
        fail(error, "Unable to load or create this client's identity");
        return nil;
    }

    // Pair over HTTP, as a new host: a pinned certificate from an earlier
    // pairing would make serverinfo use HTTPS.
    HostConfig host;
    host.address = toStd(address);
    std::string message;
    if (!fetchServerInfo(host, client, message, token)) {
        fail(error, message, cancellation);
        return nil;
    }

    std::string serverCert;
    switch (pairHost(host.address, host.httpPort, host.httpsPort, host.appVersion,
                     client.uniqueId, toStd(pin), serverCert, message, token)) {
    case PairState::Paired:
        break;
    case PairState::PinWrong:
        fail(error, "The PIN entered on the computer was wrong. Try again.");
        return nil;
    case PairState::AlreadyInProgress:
    case PairState::Failed:
    default:
        fail(error, message, cancellation);
        return nil;
    }

    // Now that the host trusts us, it reports its MAC address and apps.
    host.serverCertPem = serverCert;
    std::string ignored;
    if (fetchServerInfo(host, client, ignored, token)) {
        fetchAppList(host, client, ignored, token);
    }
    host.isPaired = true;

    if (!savePairedHost(host, message)) {
        fail(error, message);
        return nil;
    }
    return [[SLHost alloc] initWithHost:host polled:YES];
}

+ (BOOL)quitAppOnHost:(NSString*)identifier
         cancellation:(SLCancellation*)cancellation
                error:(NSError**)error
{
    HostConfig host;
    if (!findSavedHost(identifier, host)) {
        return fail(error, "This computer isn't paired");
    }

    ClientConfig client = currentClient();
    std::string message;
    if (!fetchServerInfo(host, client, message, tokenOf(cancellation))) {
        return fail(error, message, cancellation);
    }
    if (host.currentGameId == 0) {
        return YES;
    }
    return quitRunningApp(host, client, message, tokenOf(cancellation)) ? YES : fail(error, message, cancellation);
}

+ (BOOL)forgetHost:(NSString*)identifier error:(NSError**)error
{
    std::string message;
    return removeSavedHost(toStd(identifier), message) ? YES : fail(error, message);
}

@end
