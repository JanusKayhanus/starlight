#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Objective-C access to the streaming core's host management (client/), for
// the Starlight UI. Every SLCore call blocks on the network, so run them off
// the main thread.

extern NSErrorDomain const SLCoreErrorDomain;

typedef NS_ERROR_ENUM(SLCoreErrorDomain, SLCoreErrorCode) {
    SLCoreErrorFailed = 1,
    SLCoreErrorCancelled = 2,
};

/// Lets another thread stop a blocking SLCore call, which then fails with
/// SLCoreErrorCancelled.
NS_SWIFT_SENDABLE
@interface SLCancellation : NSObject
- (void)cancel;
@end

/// An app the host publishes.
NS_SWIFT_SENDABLE
@interface SLApp : NSObject
@property (nonatomic, readonly) NSInteger appID;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) BOOL hdrSupported;
/// Hidden by the user in the Qt build.
@property (nonatomic, readonly) BOOL hidden;
@end

/// A host as the core knows it.
NS_SWIFT_SENDABLE
@interface SLHost : NSObject
/// The host's UUID, or its address if the UUID isn't known.
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly, copy) NSString *address;
/// True when its MAC address is known, so it can be woken.
@property (nonatomic, readonly) BOOL canWake;
/// True if the host's last serverinfo said this client is paired. Always
/// false for hosts that haven't been polled.
@property (nonatomic, readonly) BOOL paired;
/// The app the host is streaming, or 0.
@property (nonatomic, readonly) NSInteger runningAppID;
/// Saved (paired) hosts keep their app list; others have none.
@property (nonatomic, readonly, copy) NSArray<SLApp *> *apps;
@end

@interface SLCore : NSObject

/// Every host saved in Moonlight's preferences, not yet polled.
+ (NSArray<SLHost *> *)savedHosts;

/// Polls a host's serverinfo. Uses the saved host with this identifier, or
/// else asks `address` over HTTP as an unpaired host.
+ (nullable SLHost *)fetchStatusOfHost:(NSString *)identifier
                               address:(NSString *)address
                          cancellation:(nullable SLCancellation *)cancellation
                                 error:(NSError **)error
    NS_SWIFT_NAME(fetchStatus(ofHost:address:cancellation:));

/// Fetches a saved host's app list (including hidden apps) and saves it.
+ (nullable NSArray<SLApp *> *)fetchAppsOfHost:(NSString *)identifier
                                  cancellation:(nullable SLCancellation *)cancellation
                                         error:(NSError **)error
    NS_SWIFT_NAME(fetchApps(ofHost:cancellation:));

/// Sends Wake-on-LAN packets to a saved host.
+ (BOOL)wakeHost:(NSString *)identifier error:(NSError **)error
    NS_SWIFT_NAME(wake(host:));

/// Looks up a host by name or address. Returns the saved host if it's one.
+ (nullable SLHost *)resolveAddress:(NSString *)address
                       cancellation:(nullable SLCancellation *)cancellation
                              error:(NSError **)error
    NS_SWIFT_NAME(resolve(address:cancellation:));

/// Pairs with the host at `address` using `pin`, which the user enters on the
/// host, and saves it. Waits until the PIN is entered or `cancellation` is
/// cancelled.
+ (nullable SLHost *)pairWithHostAtAddress:(NSString *)address
                                       pin:(NSString *)pin
                              cancellation:(nullable SLCancellation *)cancellation
                                     error:(NSError **)error
    NS_SWIFT_NAME(pair(address:pin:cancellation:));

/// Quits whatever app a saved host is running.
+ (BOOL)quitAppOnHost:(NSString *)identifier
         cancellation:(nullable SLCancellation *)cancellation
                error:(NSError **)error
    NS_SWIFT_NAME(quitApp(onHost:cancellation:));

/// Removes a saved host and its pinned certificate.
+ (BOOL)forgetHost:(NSString *)identifier error:(NSError **)error
    NS_SWIFT_NAME(forget(host:));

@end

NS_ASSUME_NONNULL_END
