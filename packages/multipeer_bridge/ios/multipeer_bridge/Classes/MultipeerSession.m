#import "MultipeerSession.h"
#import <UIKit/UIKit.h>

static NSString *const kEventType = @"type";
static NSString *const kEventStarted = @"started";
static NSString *const kEventStopped = @"stopped";
static NSString *const kEventPeerChanged = @"peerChanged";
static NSString *const kEventData = @"data";
static NSString *const kEventError = @"error";

@interface MultipeerSession ()
@property(nonatomic, strong) MCPeerID *localPeerID;
@property(nonatomic, strong, nullable) MCSession *session;
@property(nonatomic, strong, nullable) MCNearbyServiceAdvertiser *advertiser;
@property(nonatomic, strong, nullable) MCNearbyServiceBrowser *browser;
@property(nonatomic, strong) NSMutableDictionary<NSString *, MCPeerID *> *peersById;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *peerStates;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *invites;
@end

@implementation MultipeerSession {
  dispatch_queue_t _queue;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _peersById = [NSMutableDictionary dictionary];
    _peerStates = [NSMutableDictionary dictionary];
    _invites = [NSMutableDictionary dictionary];
    _queue = dispatch_queue_create("app.multipeer_bridge", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

#pragma mark - Lifecycle

- (void)startWithServiceType:(NSString *)serviceType
                 displayName:(NSString *)displayName
                     onEvent:(MultipeerEventHandler)onEvent {
  self.onEvent = onEvent;

  // MultipeerConnectivity caps peer display names; keep it short and valid.
  NSString *name = [self sanitizeDisplayName:displayName];
  self.localPeerID = [[MCPeerID alloc] initWithDisplayName:name];

  self.session = [[MCSession alloc] initWithPeer:self.localPeerID
                                  securityIdentity:nil
                                  encryptionPreference:MCEncryptionRequired];

  self.advertiser = [[MCNearbyServiceAdvertiser alloc]
      initWithPeer:self.localPeerID
        discoveryInfo:nil
      serviceType:serviceType];
  self.advertiser.delegate = self;
  [self.advertiser startAdvertisingPeer];

  self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.localPeerID
                                                  serviceType:serviceType];
  self.browser.delegate = self;
  [self.browser startBrowsingForPeers];

  // Seed states for peers already in the session.
  for (MCPeerID *peer in self.session.connectedPeers) {
    self.peerStates[peer.displayName] = @"connected";
  }

  [self emit:@{kEventType : kEventStarted, @"displayName" : name}];
}

- (void)stop {
  [self.advertiser stopAdvertisingPeer];
  [self.browser stopBrowsingForPeers];
  self.advertiser = nil;
  self.browser = nil;

  [self.session disconnect];
  self.session = nil;

  [self.peersById removeAllObjects];
  [self.peerStates removeAllObjects];
  [self.invites removeAllObjects];

  [self emit:@{kEventType : kEventStopped}];
}

- (NSString *)sanitizeDisplayName:(NSString *)name {
  NSCharacterSet *allowed =
      [NSCharacterSet characterSetWithCharactersInString:
                       @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
                       @"0123456789 -_"];
  NSMutableString *result = [NSMutableString string];
  for (NSUInteger i = 0; i < name.length && result.length < 63; i++) {
    unichar c = [name characterAtIndex:i];
    if ([allowed characterIsMember:c]) {
      [result appendFormat:@"%C", c];
    }
  }
  if (result.length == 0) {
    return @"iPhone";
  }
  return result;
}

- (NSString *)resolvedDeviceName {
  if (self.localPeerID.displayName.length > 0) {
    return self.localPeerID.displayName;
  }
  return UIDevice.currentDevice.name;
}

#pragma mark - Sending

- (BOOL)sendData:(NSString *)data
    toPeerWithId:(NSString *)peerId
           error:(NSError *_Nullable *_Nullable)error {
  MCPeerID *peer = self.peersById[peerId];
  if (peer == nil) {
    if (error) {
      *error = [NSError errorWithDomain:@"multipeer_bridge"
                                   code:404
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Peer is not connected"
                               }];
    }
    return NO;
  }

  NSData *payload = [data dataUsingEncoding:NSUTF8StringEncoding];
  if (payload == nil) {
    if (error) {
      *error = [NSError errorWithDomain:@"multipeer_bridge"
                                   code:400
                               userInfo:@{
                                 NSLocalizedDescriptionKey :
                                     @"Data could not be encoded"
                               }];
    }
    return NO;
  }

  NSError *sendError = nil;
  [self.session sendData:payload
                 toPeers:@[ peer ]
            withMode:MCSessionSendDataReliable
                 error:&sendError];
  if (sendError != nil) {
    if (error) *error = sendError;
    return NO;
  }
  return YES;
}

- (void)invitePeerWithId:(NSString *)peerId {
  MCPeerID *peer = self.peersById[peerId];
  if (peer == nil) return;
  [self.browser invitePeer:peer toSession:self.session withContext:nil timeout:30];
}

#pragma mark - Emitting

- (void)emit:(NSDictionary *)event {
  MultipeerEventHandler handler = self.onEvent;
  if (handler == nil) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    handler(event);
  });
}

- (void)emitPeerChanged {
  NSMutableArray *peers = [NSMutableArray array];
  for (NSString *key in self.peersById) {
    MCPeerID *peer = self.peersById[key];
    [peers addObject:@{
      @"id" : key,
      @"name" : peer.displayName,
      @"state" : self.peerStates[key] ?: @"notConnected",
    }];
  }
  [self emit:@{kEventType : kEventPeerChanged, @"peers" : peers}];
}

- (NSString *)stateNameFor:(MCPeerID *)peer {
  if (self.session == nil) return @"notConnected";
  return self.peerStates[peer.displayName] ?: @"notConnected";
}

- (void)emitError:(NSString *)message {
  [self emit:@{kEventType : kEventError, @"message" : message ?: @"Unknown error"}];
}

#pragma mark - MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
    didReceiveInvitationFromPeer:(MCPeerID *)peerID
                     withContext:(NSData *)context
               invitationHandler:(void (^)(BOOL, MCSession *_Nullable))
                                    invitationHandler {
  // Auto-accept: the app only ever shares with a user-presented sheet.
  self.peersById[peerID.displayName] = peerID;
  self.peerStates[peerID.displayName] = @"connecting";
  invitationHandler(YES, self.session);
  [self emitPeerChanged];
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser
    didNotStartAdvertisingPeer:(NSError *)error {
  [self emitError:error.localizedDescription];
}

#pragma mark - MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser
         foundPeer:(MCPeerID *)peerID
      withDiscoveryInfo:(NSDictionary<NSString *, NSString *> *)info {
  self.peersById[peerID.displayName] = peerID;
  if (self.peerStates[peerID.displayName] == nil) {
    self.peerStates[peerID.displayName] = @"notConnected";
  }
  [self emitPeerChanged];
}

- (void)browser:(MCNearbyServiceBrowser *)browser
      lostPeer:(MCPeerID *)peerID {
  [self.peersById removeObjectForKey:peerID.displayName];
  [self.peerStates removeObjectForKey:peerID.displayName];
  [self emitPeerChanged];
}

- (void)browser:(MCNearbyServiceBrowser *)browser
    didNotStartBrowsingForPeers:(NSError *)error {
  [self emitError:error.localizedDescription];
}

#pragma mark - MCSessionDelegate

- (void)session:(MCSession *)session
              peer:(MCPeerID *)peerID
    didChangeState:(MCSessionState)state {
  switch (state) {
    case MCSessionStateConnected:
      self.peersById[peerID.displayName] = peerID;
      self.peerStates[peerID.displayName] = @"connected";
      break;
    case MCSessionStateConnecting:
      self.peersById[peerID.displayName] = peerID;
      self.peerStates[peerID.displayName] = @"connecting";
      break;
    case MCSessionStateNotConnected:
      [self.peersById removeObjectForKey:peerID.displayName];
      [self.peerStates removeObjectForKey:peerID.displayName];
      break;
  }
  [self emitPeerChanged];
}

- (void)session:(MCSession *)session
    didReceiveData:(NSData *)data
          fromPeer:(MCPeerID *)peerID {
  NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  if (text == nil) {
    [self emitError:@"Received undecodable data"];
    return;
  }
  [self emit:@{kEventType : kEventData, @"data" : text, @"from" : peerID.displayName}];
}

- (void)session:(MCSession *)session
    didReceiveStream:(NSInputStream *)stream
            withName:(NSString *)streamName
            fromPeer:(MCPeerID *)peerID {
  // Unused: this bridge only sends small, self-contained payloads.
}

- (void)session:(MCSession *)session
    didStartReceivingResourceWithName:(NSString *)resourceName
                             fromPeer:(MCPeerID *)peerID
                         withProgress:(NSProgress *)progress {
  // Unused: no resource transfers.
}

- (void)session:(MCSession *)session
    didFinishReceivingResourceWithName:(NSString *)resourceName
                              fromPeer:(MCPeerID *)peerID
                                 atURL:(NSURL *)localURL
                             withError:(NSError *)error {
  // Unused: no resource transfers.
}

@end
