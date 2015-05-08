#import "VideoView.h"

@implementation VideoView

- (void)setupVideoLayer {
    self.videoLayer = [AVSampleBufferDisplayLayer new];
    self.videoLayer.bounds = self.bounds;
    self.videoLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.videoLayer.backgroundColor = [NSColor blueColor].CGColor;

    CMTimebaseRef controlTimebase;
    CMTimebaseCreateWithMasterClock( CFAllocatorGetDefault(), CMClockGetHostTimeClock(), &controlTimebase);

    self.videoLayer.controlTimebase = controlTimebase;
    CMTimebaseSetTime(self.videoLayer.controlTimebase, CMTimeMake(5, 1));
    CMTimebaseSetRate(self.videoLayer.controlTimebase, 1.0);

    self.videoLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;

    [self setWantsLayer:YES];
    [self.layer addSublayer:self.videoLayer];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        [self setupVideoLayer];
    }

    return self;
}

@end
