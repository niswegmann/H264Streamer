#import <Cocoa/Cocoa.h>

@import AVFoundation;

@interface VideoView : NSView

@property (nonatomic, strong) AVSampleBufferDisplayLayer * videoLayer;

@end
