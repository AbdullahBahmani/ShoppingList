#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MultipeerEventHandler)(NSDictionary *event);

/// Wraps an MCSession and advertises + browses so two devices can exchange
/// small payloads directly over peer-to-peer WiFi or Bluetooth.
@interface MultipeerSession : NSObject <MCSessionDelegate,
                                        MCNearbyServiceAdvertiserDelegate,
                                        MCNearbyServiceBrowserDelegate>

@property(nonatomic, copy, nullable) MultipeerEventHandler onEvent;

- (void)startWithServiceType:(NSString *)serviceType
                 displayName:(NSString *)displayName
                     onEvent:(MultipeerEventHandler)onEvent;
- (void)stop;
- (BOOL)sendData:(NSString *)data
    toPeerWithId:(NSString *)peerId
           error:(NSError *_Nullable *_Nullable)error;
- (void)invitePeerWithId:(NSString *)peerId;

/// A short, human-friendly name for this device, best effort.
- (NSString *)resolvedDeviceName;

@end

NS_ASSUME_NONNULL_END
