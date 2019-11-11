#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef enum : NSUInteger {
    OYERecordManagerAudioAuthStatusUnknow,
    OYERecordManagerAudioAuthStatusNoAuth,
    OYERecordManagerAudioAuthStatusAuth
} OYERecordManagerAudioAuthStatus;

@protocol OYERecordManagerDelegate <NSObject>
@optional

@end

@interface DKRecordManager : NSObject
+ (DKRecordManager *)sharedManager;
@property (assign, nonatomic) id <OYERecordManagerDelegate> delegate;
/// 音量检测
/// @param able able
- (void)setMeteringEnable:(BOOL)able;
/// 设置最大时间
/// @param time time
- (void)setMaxRecordTime:(NSInteger)time;
/// 设置最小时间
/// @param time time
- (void)setMinRecordTime:(NSInteger)time;
/// 通配参数
/// @param format format
/// @param rate rate
/// @param channel channel
/// @param linearPCMBitDepth linearPCMBitDepth
/// @param linearPCMIsFloat linearPCMIsFloat
- (void)setObjectFormat:(NSObject *)format // 设置录音格式 @(kAudioFormatMPEG4AAC)
                   rate:(NSObject *)rate // 设置录音采样率，8000是电话采样率 @(8000)
                channel:(NSObject *)channel // 设置通道 @(1)
      linearPCMBitDepth:(NSObject *)linearPCMBitDepth // 每个采样点位数 @(8)
       linearPCMIsFloat:(NSObject *)linearPCMIsFloat; // 是否使用浮点数采样 @(YES)
/// 必须先设置参数
- (BOOL)createRecorder;
/// 删除录音recorder
- (void)removeRecorder;
/// 开始录音
- (void)startRecorder;
/// 结束录音
- (void)stopRecorder;
/// 移除录音文件
- (BOOL)removeRecordFile;
/// 获取录音文件
- (NSURL *)getFileURL;
/// 移除代理
- (void)removeDelegate;
/// 取消
- (void)cancelRecorder;

#pragma mark --
#pragma mark -- PRIVATE 工具类

/// 获取权限
+ (OYERecordManagerAudioAuthStatus)getAudioAuth;
@end

