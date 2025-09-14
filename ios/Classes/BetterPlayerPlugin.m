// تعديلات على BetterPlayerPlugin.m الموجود

#import "BetterPlayerPlugin.h"
#import <better_player/better_player-Swift.h>

#if !__has_feature(objc_arc)
#error Code Requires ARC.
#endif

@implementation BetterPlayerPlugin
NSMutableDictionary* _dataSourceDict;
NSMutableDictionary* _timeObserverIdDict;
NSMutableDictionary* _artworkImageDict;
// ✅ إضافة للـ Auto PiP
NSMutableDictionary* _autoPipEnabledDict;
CacheManager* _cacheManager;
int texturesCount = -1;
BetterPlayer* _notificationPlayer;
bool _remoteCommandsInitialized = false;

#pragma mark - FlutterPlugin protocol
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel =
            [FlutterMethodChannel methodChannelWithName:@"better_player_channel"
                                        binaryMessenger:[registrar messenger]];
    BetterPlayerPlugin* instance = [[BetterPlayerPlugin alloc] initWithRegistrar:registrar];
    [registrar addMethodCallDelegate:instance channel:channel];
    [registrar registerViewFactory:instance withId:@"com.jhomlala/better_player"];
}

- (instancetype)initWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _messenger = [registrar messenger];
    _registrar = registrar;
    _players = [NSMutableDictionary dictionaryWithCapacity:1];
    _timeObserverIdDict = [NSMutableDictionary dictionary];
    _artworkImageDict = [NSMutableDictionary dictionary];
    _dataSourceDict = [NSMutableDictionary dictionary];
    // ✅ إضافة للـ Auto PiP tracking
    _autoPipEnabledDict = [NSMutableDictionary dictionary];
    _cacheManager = [[CacheManager alloc] init];
    [_cacheManager setup];

    // ✅ إعداد الnotifications للapp lifecycle
    [self setupAppLifecycleNotifications];

    return self;
}

// ✅ إعداد الnotifications للapp lifecycle
- (void)setupAppLifecycleNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

// ✅ لما الapp يروح background
- (void)appDidEnterBackground:(NSNotification *)notification {
    // تحقق من كل الplayers اللي auto pip enabled
    for (NSNumber* textureId in _autoPipEnabledDict.allKeys) {
        BOOL autoPipEnabled = [[_autoPipEnabledDict objectForKey:textureId] boolValue];

        if (autoPipEnabled) {
            BetterPlayer* player = _players[textureId];

            // تحقق إن الplayer شغال
            if (player && player.isPlaying) {
                // تفعيل PiP تلقائياً
                [self enableAutoPictureInPictureForPlayer:player withTextureId:textureId];
            }
        }
    }
}

// ✅ لما الapp يرجع foreground
- (void)appWillEnterForeground:(NSNotification *)notification {
    // إرسال event للFlutter إن PiP خلص
    for (NSNumber* textureId in _autoPipEnabledDict.allKeys) {
        [self sendPipEventToFlutter:@"pipStopped" withTextureId:textureId withData:nil];
    }
}

// ✅ تفعيل Auto PiP لplayer معين
- (void)enableAutoPictureInPictureForPlayer:(BetterPlayer*)player withTextureId:(NSNumber*)textureId {
    if (@available(iOS 9.0, *)) {
        if ([AVPictureInPictureController isPictureInPictureSupported]) {
            // استخدام default frame للPiP
            CGRect pipFrame = CGRectMake(0, 0, 200, 112); // 16:9 ratio
            [player enablePictureInPicture:pipFrame];

            // إرسال event للFlutter
            [self sendPipEventToFlutter:@"pipStarted" withTextureId:textureId withData:nil];
        } else {
            [self sendPipEventToFlutter:@"pipError" withTextureId:textureId withData:@"PiP not supported"];
        }
    } else {
        [self sendPipEventToFlutter:@"pipError" withTextureId:textureId withData:@"iOS version not supported"];
    }
}

// ✅ إرسال events للFlutter
- (void)sendPipEventToFlutter:(NSString*)eventType withTextureId:(NSNumber*)textureId withData:(NSString*)data {
    FlutterMethodChannel* channel = [FlutterMethodChannel
            methodChannelWithName:@"better_player_channel"
                  binaryMessenger:_messenger];

    NSMutableDictionary* arguments = [NSMutableDictionary dictionary];
    [arguments setObject:eventType forKey:@"event"];
    [arguments setObject:textureId forKey:@"textureId"];

    if (data != nil) {
        [arguments setObject:data forKey:@"data"];
    }

    [channel invokeMethod:@"onPipEvent" arguments:arguments];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"init" isEqualToString:call.method]) {
        // Allow audio playback when the Ring/Silent switch is set to silent
        for (NSNumber* textureId in _players) {
            [_players[textureId] dispose];
        }
        [_players removeAllObjects];
        [_autoPipEnabledDict removeAllObjects]; // ✅ تنظيف الاuto pip
        result(nil);
    }
        // ✅ إضافة method جديد للAuto PiP
    else if ([@"enableAutoPip" isEqualToString:call.method]) {
        NSDictionary* argsMap = call.arguments;
        int64_t textureId = ((NSNumber*)argsMap[@"textureId"]).unsignedIntegerValue;

        // حفظ حالة الAuto PiP للplayer ده
        [_autoPipEnabledDict setObject:@(YES) forKey:@(textureId)];

        result(@(YES));
    }
        // ✅ إضافة method لإيقاف Auto PiP
    else if ([@"disableAutoPip" isEqualToString:call.method]) {
        NSDictionary* argsMap = call.arguments;
        int64_t textureId = ((NSNumber*)argsMap[@"textureId"]).unsignedIntegerValue;

        // إزالة حالة الAuto PiP للplayer ده
        [_autoPipEnabledDict removeObjectForKey:@(textureId)];

        result(@(NO));
    }
        // ✅ إضافة method للتحقق من حالة PiP
    else if ([@"isPipActive" isEqualToString:call.method]) {
        NSDictionary* argsMap = call.arguments;
        int64_t textureId = ((NSNumber*)argsMap[@"textureId"]).unsignedIntegerValue;
        BetterPlayer* player = _players[@(textureId)];

        if (player) {
            result(@(player.pictureInPicture));
        } else {
            result(@(NO));
        }
    }
    else if ([@"create" isEqualToString:call.method]) {
        BetterPlayer* player = [[BetterPlayer alloc] initWithFrame:CGRectZero];
        [self onPlayerSetup:player result:result];
    } else {
        NSDictionary* argsMap = call.arguments;
        int64_t textureId = ((NSNumber*)argsMap[@"textureId"]).unsignedIntegerValue;
        BetterPlayer* player = _players[@(textureId)];

        if ([@"setDataSource" isEqualToString:call.method]) {
            // ... الكود الموجود للsetDataSource
            [player clear];

            NSDictionary* dataSource = argsMap[@"dataSource"];
            [_dataSourceDict setObject:dataSource forKey:[self getTextureId:player]];

            // باقي الكود الموجود...
            result(nil);

        } else if ([@"dispose" isEqualToString:call.method]) {
            [player clear];
            [self disposeNotificationData:player];
            [self setRemoteCommandsNotificationNotActive];

            // ✅ تنظيف الauto pip data
            [_autoPipEnabledDict removeObjectForKey:@(textureId)];

            [_players removeObjectForKey:@(textureId)];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                        if (!player.disposed) {
                            [player dispose];
                        }
                    });

            if ([_players count] == 0) {
                [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
            }
            result(nil);

        } else if ([@"enablePictureInPicture" isEqualToString:call.method]){
            double left = [argsMap[@"left"] doubleValue];
            double top = [argsMap[@"top"] doubleValue];
            double width = [argsMap[@"width"] doubleValue];
            double height = [argsMap[@"height"] doubleValue];
            [player enablePictureInPicture:CGRectMake(left, top, width, height)];

            // ✅ إرسال event للFlutter
            [self sendPipEventToFlutter:@"pipStarted" withTextureId:@(textureId) withData:nil];

            result(nil);

        } else if ([@"isPictureInPictureSupported" isEqualToString:call.method]){
            if (@available(iOS 9.0, *)){
                if ([AVPictureInPictureController isPictureInPictureSupported]){
                    result([NSNumber numberWithBool:true]);
                    return;
                }
            }
            result([NSNumber numberWithBool:false]);

        } else if ([@"disablePictureInPicture" isEqualToString:call.method]){
            [player disablePictureInPicture];
            [player setPictureInPicture:false];

            // ✅ إرسال event للFlutter
            [self sendPipEventToFlutter:@"pipStopped" withTextureId:@(textureId) withData:nil];

            result(nil);

        } else {
            // باقي الmethods الموجودة...
            result(FlutterMethodNotImplemented);
        }
    }
}

// ✅ تنظيف الnotifications
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end