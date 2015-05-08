#import "ViewController.h"

#import "NALUTypes.h"
#import "VideoView.h"

@import AVKit;

typedef enum {
    NALUTypeSliceNoneIDR = 1,
    NALUTypeSliceIDR = 5,
    NALUTypeSPS = 7,
    NALUTypePPS = 8
} NALUType;

@interface ViewController ()

@property (nonatomic, strong, readonly) VideoView * videoView;
@property (nonatomic, strong) NSData * spsData;
@property (nonatomic, strong) NSData * ppsData;
@property (nonatomic) CMVideoFormatDescriptionRef videoFormatDescr;
@property (nonatomic) BOOL videoFormatDescriptionAvailable;

@end

@implementation ViewController

- (VideoView *)videoView {
    return (VideoView *) self.view;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        _videoFormatDescriptionAvailable = NO;
    }

    return self;
}

- (int)getNALUType:(NSData *)NALU {
    uint8_t * bytes = (uint8_t *) NALU.bytes;

    return bytes[0] & 0x1F;
}

- (void)handleSlice:(NSData *)NALU {
    if (self.videoFormatDescriptionAvailable) {
        /* The length of the NALU in big endian */
        const uint32_t NALUlengthInBigEndian = CFSwapInt32HostToBig((uint32_t) NALU.length);

        /* Create the slice */
        NSMutableData * slice = [[NSMutableData alloc] initWithBytes:&NALUlengthInBigEndian length:4];

        /* Append the contents of the NALU */
        [slice appendData:NALU];

        /* Create the video block */
        CMBlockBufferRef videoBlock = NULL;

        OSStatus status;

        status =
            CMBlockBufferCreateWithMemoryBlock
                (
                    NULL,
                    (void *) slice.bytes,
                    slice.length,
                    kCFAllocatorNull,
                    NULL,
                    0,
                    slice.length,
                    0,
                    & videoBlock
                );

        NSLog(@"BlockBufferCreation: %@", (status == kCMBlockBufferNoErr) ? @"successfully." : @"failed.");

        /* Create the CMSampleBuffer */
        CMSampleBufferRef sbRef = NULL;

        const size_t sampleSizeArray[] = { slice.length };

        status =
            CMSampleBufferCreate
                (
                    kCFAllocatorDefault,
                    videoBlock,
                    true,
                    NULL,
                    NULL,
                    _videoFormatDescr,
                    1,
                    0,
                    NULL,
                    1,
                    sampleSizeArray,
                    & sbRef
                );

        NSLog(@"SampleBufferCreate: %@", (status == noErr) ? @"successfully." : @"failed.");

        /* Enqueue the CMSampleBuffer in the AVSampleBufferDisplayLayer */
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sbRef, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);

        NSLog(@"Error: %@, Status: %@",
              self.videoView.videoLayer.error,
                (self.videoView.videoLayer.status == AVQueuedSampleBufferRenderingStatusUnknown)
                    ? @"unknown"
                    : (
                        (self.videoView.videoLayer.status == AVQueuedSampleBufferRenderingStatusRendering)
                            ? @"rendering"
                            :@"failed"
                      )
             );

        dispatch_async(dispatch_get_main_queue(),^{
            [self.videoView.videoLayer enqueueSampleBuffer:sbRef];
            [self.videoView.videoLayer setNeedsDisplay];
        });

        NSLog(@" ");
    }
}

- (void)handleSPS:(NSData *)NALU {
    _spsData = [NALU copy];
}

- (void)handlePPS:(NSData *)NALU {
    _ppsData = [NALU copy];
}

- (void)updateFormatDescriptionIfPossible {
    if (_spsData != nil && _ppsData != nil) {
        const uint8_t * const parameterSetPointers[2] = {
            (const uint8_t *) _spsData.bytes,
            (const uint8_t *) _ppsData.bytes
        };

        const size_t parameterSetSizes[2] = {
            _spsData.length,
            _ppsData.length
        };

        OSStatus status =
            CMVideoFormatDescriptionCreateFromH264ParameterSets
                (
                    kCFAllocatorDefault,
                    2,
                    parameterSetPointers,
                    parameterSetSizes,
                    4,
                    & _videoFormatDescr
                );

        _videoFormatDescriptionAvailable = YES;

        NSLog(@"Updated CMVideoFormatDescription. Creation: %@.", (status == noErr) ? @"successfully." : @"failed.");
    }
}

- (void)parseNALU:(NSData *)NALU {
    int type = [self getNALUType: NALU];

    NSLog(@"NALU with Type \"%@\" received.", naluTypesStrings[type]);

    switch (type)
    {
        case NALUTypeSliceNoneIDR:
        case NALUTypeSliceIDR:
            [self handleSlice:NALU];
            break;
        case NALUTypeSPS:
            [self handleSPS:NALU];
            [self updateFormatDescriptionIfPossible];
            break;
        case NALUTypePPS:
            [self handlePPS:NALU];
            [self updateFormatDescriptionIfPossible];
            break;
        default:
            break;
    }
}

- (IBAction)streamVideo:(id)sender {
    NSBundle * mainBundle = [NSBundle mainBundle];

    for (int k = 0; k < 1000; k++) {
        NSString * resource = [NSString stringWithFormat:@"nalu_%03d", k];
        NSString * path = [mainBundle pathForResource:resource ofType:@"bin"];
        NSData * NALU = [NSData dataWithContentsOfFile:path];
        [self parseNALU:NALU];
    }
}

@end
