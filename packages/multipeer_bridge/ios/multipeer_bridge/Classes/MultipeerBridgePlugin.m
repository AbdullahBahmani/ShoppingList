#import "MultipeerBridgePlugin.h"
#import "MultipeerSession.h"

@implementation MultipeerBridgePlugin {
  MultipeerSession *_session;
  FlutterMethodChannel *_channel;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  MultipeerBridgePlugin *instance = [[MultipeerBridgePlugin alloc] init];
  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:@"multipeer_bridge"
            binaryMessenger:[registrar messenger]];
  instance->_channel = channel;
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _session = [[MultipeerSession alloc] init];
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSDictionary *args =
      [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};

  if ([@"start" isEqualToString:call.method]) {
    [_session startWithServiceType:args[@"serviceType"] ?: @"shoplist"
                       displayName:args[@"displayName"] ?: @""
                         onEvent:^(NSDictionary *event) {
                           [self->_channel invokeMethod:@"event" arguments:event];
                         }];
    result(nil);
    return;
  }

  if ([@"stop" isEqualToString:call.method]) {
    [_session stop];
    result(nil);
    return;
  }

  if ([@"invite" isEqualToString:call.method]) {
    [_session invitePeerWithId:args[@"peerId"]];
    result(nil);
    return;
  }

  if ([@"send" isEqualToString:call.method]) {
    NSError *error = nil;
    BOOL sent = [_session sendData:args[@"data"] ?: @""
                       toPeerWithId:args[@"peerId"]
                              error:&error];
    if (!sent) {
      result([FlutterError errorWithCode:@"send_failed"
                                 message:error.localizedDescription ?: @"Send failed"
                                 details:nil]);
      return;
    }
    result(nil);
    return;
  }

  if ([@"deviceName" isEqualToString:call.method]) {
    result([_session resolvedDeviceName]);
    return;
  }

  result(FlutterMethodNotImplemented);
}

@end
