//
//  PayCardsRecognizer.m
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 04/12/15.
//  Copyright © 2015 Vladimir Tchernitski. All rights reserved.
//

#import "PayCardsRecognizer.h"

#include "INeuralNetworkObjectFactory.h"
#include "INeuralNetworkDatum.h"
#include "INeuralNetworkDatumList.h"
#include "INeuralNetworkResultList.h"
#include "INeuralNetworkResult.h"

#include "IFrameStorage.h"
#include "IEdgesDetector.h"
#include "IRecognitionResult.h"
#include "IRecognitionCore.h"

#include "IRecognitionCoreDelegate.h"
#include "ITorchDelegate.h"
#include "IRecognitionCore.h"

#import "WOUtils.h"
#import "WOEdgesWrapperView.h"

#import "GPUImageVideoCamera.h"
#import "GPUImageView.h"
#import "WOTorchDelegate.h"
#import "Enums.h"

NSString* const WOCardNumber = @"RecognizedCardNumber";
NSString* const WOExpDate = @"RecognizedExpDate";
NSString* const WOHolderName = @"RecognizedHolderName";
NSString* const WOHolderNameRaw = @"RecognizedHolderNameRaw";
NSString* const WONumberConfidences = @"ConfidencesOfRecognizedNumber";
NSString* const WOHolderNameConfidences = @"ConfidencesOfRecognizedHolderName";
NSString* const WOExpDateConfidences = @"ConfidencesOfRecognizedExpDate";
NSString* const WOCardImage = @"AlignedCardImage";
NSString* const WODateRectImage = @"DateRectImage";
NSString* const WOPanRect = @"PanRect";
NSString* const WODateRect = @"DateRect";

NSString *const kBundleIdentifier = @"com.walletone.ios.PayCardsRecognizer";

using namespace std;

@implementation UIView (Autolayout)

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr {
    return [self addConstraintWithItem:item attribute:attr toItem:self];
}

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr toItem:(UIView *)toItem {
    return [self addConstraintWithItem:item attribute:attr toItem:toItem attribute:attr];
}

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr1 toItem:(UIView *)toItem attribute:(NSLayoutAttribute)attr2 {
    return [self addConstraintWithItem:item attribute:attr1 toItem:toItem attribute:attr2 constant: 0.0];
}

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr1 toItem:(UIView *)toItem attribute:(NSLayoutAttribute)attr2 constant:(CGFloat)constant {
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:item attribute:attr1 relatedBy:NSLayoutRelationEqual toItem:toItem attribute:attr2 multiplier:1.0 constant:constant];
    [self addConstraint:constraint];
    return constraint;
}

@end

@implementation NSString (CreditCard)

- (NSString *)formatCreditCard {
    
    NSMutableString *str = [NSMutableString stringWithString:self];
    int indx=4;
    while (indx<str.length) {
        [str insertString:@"  " atIndex:indx];
        indx +=6;
    }
    
    return str;
}

- (NSString *)formatDate {
    if (self.length < 4) {
        return self;
    } else {
        NSString *month = [self substringToIndex:2];
        NSString *year = [self substringFromIndex:2];
        return [NSString stringWithFormat:@"%@ / %@", month, year];
    }
}

@end

@interface PayCardsRecognizer () <GPUImageVideoCameraDelegate, WOTorchPlatformDelegate> {

    size_t _bufferSizeY;
    size_t _bufferSizeUV;
    
    PayCardsRecognizerOrientation _orientation;
    
    int _captureAreaWidth;
}

@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;

@property (nonatomic, strong) NSLayoutConstraint *heightConstraint;

@property (nonatomic, strong) GPUImageVideoCamera *videoCamera;

@property (nonatomic, strong) UIImageView *frameImageView;

@property (nonatomic, strong) UIView *labelsHolderView;

@property (nonatomic, assign) shared_ptr<IRecognitionCore> recognitionCore;

@property (nonatomic, strong) WOEdgesWrapperView *edgesWrapperView;

@property (nonatomic, strong) GPUImageView *view;

@property (nonatomic, weak) UIView *container;

@property (nonatomic, strong) UILabel *recognizedNumberLabel;

@property (nonatomic, strong) UILabel *recognizedNameLabel;

@property (nonatomic, strong) UILabel *recognizedDateLabel;

@property (nonatomic, strong) UIButton *copyrightButton;

@property (nonatomic, assign) PayCardsRecognizerResultMode resultMode;

@property (nonatomic, assign) PayCardsRecognizerMode recognizerMode;

@end

@implementation PayCardsRecognizer

- (instancetype _Nonnull)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate> _Nonnull)delegate resultMode:(PayCardsRecognizerResultMode)resultMode container:(UIView * _Nonnull)container {
    return [self initWithDelegate:delegate recognizerMode:(PayCardsRecognizerDataMode)(PayCardsRecognizerDataModeNumber|PayCardsRecognizerDataModeDate|PayCardsRecognizerDataModeName|PayCardsRecognizerDataModeGrabCardImage) resultMode:resultMode container:container];
}

- (instancetype _Nonnull)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate> _Nonnull)delegate recognizerMode:(PayCardsRecognizerDataMode)recognizerMode resultMode:(PayCardsRecognizerResultMode)resultMode container:(UIView * _Nonnull)container {
    self = [super init];
    if (self) {
        
        NSInteger recognizerModeInt = recognizerMode;
        PayCardsRecognizerMode recognizerModeInternal = (PayCardsRecognizerMode)recognizerModeInt;
        
        self.delegate = delegate;
        self.container = container;
        self.resultMode = resultMode;
        self.recognizerMode = recognizerModeInternal;
        
        if([[UIDevice currentDevice]userInterfaceIdiom] == UIUserInterfaceIdiomPhone && [[UIScreen mainScreen] bounds].size.height == 480) {
            _captureAreaWidth = 16;
        } else {
            _captureAreaWidth = 32;
        }
        [self deployCameraWithMode:recognizerModeInternal];
    }
    
    return self;
}

- (void)dealloc {

}

- (std::string)getString:(NSString*)str {
    if (str && str.length > 0) {
        return [str UTF8String];
    }
    return "";
}

- (void)deployWithMode:(PayCardsRecognizerMode)mode {
    _orientation = PayCardsRecognizerOrientationUnknown;
    shared_ptr<IRecognitionCoreDelegate> coreDelegate;
    IRecognitionCoreDelegate::GetInstance(coreDelegate, (__bridge void*)_delegate, (__bridge void*)self);
    shared_ptr<ITorchDelegate> torchDelegate;
    ITorchDelegate::GetInstance(torchDelegate, (__bridge void*)self);
    IRecognitionCore::GetInstance(_recognitionCore, coreDelegate, torchDelegate);
    _recognitionCore->SetRecognitionMode(mode);
    _recognitionCore->SetPathNumberLocalizationXModel([self getString:[self pathToResource:@"loc_x.caffemodel"]]);
    _recognitionCore->SetPathNumberLocalizationXStruct([self getString:[self pathToResource:@"loc_x.prototxt"]]);
    _recognitionCore->SetPathNumberLocalizationYModel([self getString:[self pathToResource:@"loc_y.caffemodel"]]);
    _recognitionCore->SetPathNumberLocalizationYStruct([self getString:[self pathToResource:@"loc_y.prototxt"]]);
    _recognitionCore->SetPathNumberRecognitionModel([self getString:[self pathToResource:@"NumberRecognition.caffemodel"]]);
    _recognitionCore->SetPathNumberRecognitionStruct([self getString:[self pathToResource:@"NumberRecognition.prototxt"]]);
    
    _recognitionCore->SetPathDateLocalization0Model([self getString:[self pathToResource:@"DateLocalizationL0.caffemodel"]]);
    _recognitionCore->SetPathDateLocalization0Struct([self getString:[self pathToResource:@"DateLocalizationL0.prototxt"]]);
    _recognitionCore->SetPathDateLocalization1Model([self getString:[self pathToResource:@"DateLocalizationL1.caffemodel"]]);
    _recognitionCore->SetPathDateLocalization1Struct([self getString:[self pathToResource:@"DateLocalizationL1.prototxt"]]);
    _recognitionCore->SetPathDateRecognitionModel([self getString:[self pathToResource:@"DateRecognition.caffemodel"]]);
    _recognitionCore->SetPathDateRecognitionStruct([self getString:[self pathToResource:@"DateRecognition.prototxt"]]);
    
    _recognitionCore->SetPathDateLocalizationViola([self getString:[self pathToResource:@"cascade_date.xml"]]);
    _recognitionCore->SetPathNameLocalizationXModel([self getString:[self pathToResource:@"NameLocalizationX.caffemodel"]]);
    _recognitionCore->SetPathNameLocalizationXStruct([self getString:[self pathToResource:@"NameLocalizationX.prototxt"]]);
    _recognitionCore->SetPathNameYLocalizationViola([self getString:[self pathToResource:@"cascade_name.xml"]]);
    
    _recognitionCore->SetPathNameSpaceCharModel([self getString:[self pathToResource:@"NameSpaceCharRecognition.caffemodel"]]);
    _recognitionCore->SetPathNameSpaceCharStruct([self getString:[self pathToResource:@"NameSpaceCharRecognition.prototxt"]]);
    
    _recognitionCore->SetPathNameListTxt([self getString:[self pathToResource:@"names.txt"]]);
    
    _recognitionCore->Deploy();
}

- (void)deployCameraWithMode:(PayCardsRecognizerMode)mode {
    [self deployWithMode:mode];
    
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720 cameraPosition:AVCaptureDevicePositionBack];
    self.videoCamera.delegate = self;
    
    int bufferHeightY = 1280;
    int bytesPerRowY = 720;
    
    int bufferHeightUV = 640;
    int bytesPerRowUV = 720;
    
    _bufferSizeY = bufferHeightY * bytesPerRowY;
    _bufferSizeUV = bufferHeightUV * bytesPerRowUV;
}

- (void)stopCamera {
    [self pauseRecognizer];
    [self.videoCamera stopCameraCapture];
    [self.videoCamera setDelegate:nil];
    [self.videoCamera removeTarget:self.view];
    [self.view removeFromSuperview];
    self.view = nil;
    self.frameImageView = nil;
    self.edgesWrapperView = nil;
    self.widthConstraint = nil;
    self.heightConstraint = nil;
    self.recognizedNumberLabel.text = @" ";
    self.recognizedDateLabel.text = @" ";
    self.recognizedNameLabel.text = @" ";
}

- (void)startCamera {
    [self startCameraWithOrientation:UIInterfaceOrientationPortrait];
}

- (void)startCameraWithOrientation:(UIInterfaceOrientation)orientation {
    
    [self.container addSubview:self.view];
    [self autoPinToContainer];
    
    self.videoCamera.delegate = self;
    
    [self.videoCamera addTarget:self.view];
    [self.videoCamera setFixedFocuse:0.48 completion:nil];
    
    [self.videoCamera startCameraCapture];
    [self setOrientation:orientation];
    [self setIsIdle:NO];
}

- (void)torchStatusDidChange:(BOOL)status {
    [self.videoCamera turnTorchOn:status withValue:0.1];
}

- (void)turnTorchOn:(BOOL)on withValue:(float)value {
    [self.videoCamera turnTorchOn:on withValue:value];
}

- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress( pixelBuffer, 0 );

    void* bufferAddressY;
    void* bufferAddressUV;

    bufferAddressY = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    bufferAddressUV = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);

    DetectedLineFlags edgeFlags = DetectedLineNoneFlag;
    
    _recognitionCore->ProcessFrame(edgeFlags, bufferAddressY, bufferAddressUV, _bufferSizeY, _bufferSizeUV);

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    [self highlightEdges:edgeFlags];
}

- (void)resumeRecognizer {
    [self setIsIdle:NO];
}

- (void)pauseRecognizer {
    [self setIsIdle:YES];
}

- (void)setIsIdle:(BOOL)isIdle {
    _recognitionCore->SetIdle(isIdle);
    _recognitionCore->ResetResult();
}

- (void)highlightEdges:(DetectedLineFlags)edgeFlags {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            _edgesWrapperView.topEdge.alpha = edgeFlags&DetectedLineTopFlag ? 1. : 0.;
            _edgesWrapperView.bottomEdge.alpha = edgeFlags&DetectedLineBottomFlag ? 1. : 0.;
            _edgesWrapperView.leftEdge.alpha = edgeFlags&DetectedLineLeftFlag ? 1. : 0.;
            _edgesWrapperView.rightEdge.alpha = edgeFlags&DetectedLineRightFlag ? 1. : 0.;
        }];
    });
}

- (void)positionUIEdges:(cv::Rect)windowRect {
    dispatch_async(dispatch_get_main_queue(), ^{
        float coef;
        
        coef = 720.0 / self.container.bounds.size.width;
        _widthConstraint.constant = windowRect.height/coef;
        _heightConstraint.constant = windowRect.width/coef;
    });
}

- (void)setOrientation:(UIInterfaceOrientation)orientation {
    
    NSInteger _orientationRawValue = _orientation;
    NSInteger orientationRawValue = orientation;
    
    cv::Rect windowRect = _recognitionCore->CalcWorkingArea(cv::Size(1280, 720), _captureAreaWidth);
    
    if (_orientationRawValue == orientationRawValue) {
        return [self positionUIEdges:windowRect];
    }
    
    _orientation = (PayCardsRecognizerOrientation)orientation;
    
    AVCaptureConnection *connection = [self.videoCamera videoCaptureConnection];
    
    switch (orientation) {
        case PayCardsRecognizerOrientationPortrait:
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            [self.view setInputRotation:kGPUImageNoRotation atIndex:0];
            break;
        case PayCardsRecognizerOrientationPortraitUpsideDown:
            connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            [self.view setInputRotation:kGPUImageNoRotation atIndex:0];
            break;
        case PayCardsRecognizerOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            [self.view setInputRotation:kGPUImageRotateRight atIndex:0];
            break;
        case PayCardsRecognizerOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            [self.view setInputRotation:kGPUImageRotateRight atIndex:0];
            break;
        default:
            break;
    }
    
    _recognitionCore->SetOrientation((PayCardsRecognizerOrientation)orientation);
    
    [self positionUIEdges:windowRect];
}

- (NSBundle *)bundle {
    return [NSBundle bundleWithIdentifier:kBundleIdentifier];
}

- (NSString *)pathToResource:(NSString *)fileName {
    NSString *path = [[self bundle] pathForResource:fileName ofType:nil];
    
    if ([self fileExistsInProject:path]) {
        return path;
    }
    return nil;
}

- (BOOL)fileExistsInProject:(NSString *)fileName {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:fileName];
}

- (void)autoPinToContainer {
    [self.container addConstraintWithItem:self.view attribute:NSLayoutAttributeTop];
    [self.container addConstraintWithItem:self.view attribute:NSLayoutAttributeRight];
    [self.container addConstraintWithItem:self.view attribute:NSLayoutAttributeBottom];
    [self.container addConstraintWithItem:self.view attribute:NSLayoutAttributeLeft];
}

@end

@implementation PayCardsRecognizer (CardDataDrawer)

- (CGFloat)fontSize:(CGFloat)base {
    CGFloat scale = self.labelsHolderView.bounds.size.width / 374;
    CGFloat fontSize = base * scale;
    return fontSize;
}

- (void)placeNumber:(NSString *)number {
    
    self.recognizedNumberLabel.text = [number formatCreditCard];
    self.recognizedNumberLabel.font = [UIFont systemFontOfSize:[self fontSize:26]];
}

- (void)placeDate:(NSString *)date {
    self.recognizedDateLabel.text = [date formatDate];
    self.recognizedDateLabel.font = [UIFont systemFontOfSize:[self fontSize:17]];
}

- (void)placeName:(NSString *)name {
    self.recognizedNameLabel.text = name;
    self.recognizedNameLabel.font = [UIFont systemFontOfSize:[self fontSize:19]];
}

@end

@implementation PayCardsRecognizer (UIInitializations)

- (UIView *)view {
    if (_view) {
        return _view;
    }
    
    _view = [[GPUImageView alloc] initWithFrame:self.container.bounds];
    _view.translatesAutoresizingMaskIntoConstraints = NO;
    _view.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    
    [_view addSubview:self.frameImageView];
    
    [_view addConstraintWithItem:self.frameImageView attribute:NSLayoutAttributeCenterX];
    [_view addConstraintWithItem:self.frameImageView attribute:NSLayoutAttributeCenterY];
    
    [_view addSubview:self.edgesWrapperView];
    
    [_view addConstraintWithItem:self.edgesWrapperView attribute:NSLayoutAttributeWidth toItem:self.frameImageView];
    [_view addConstraintWithItem:self.edgesWrapperView attribute:NSLayoutAttributeHeight toItem:self.frameImageView];
    
    [_view addConstraintWithItem:self.edgesWrapperView attribute:NSLayoutAttributeCenterX];
    [_view addConstraintWithItem:self.edgesWrapperView attribute:NSLayoutAttributeCenterY];
    
    _widthConstraint = [_view addConstraintWithItem:self.frameImageView attribute:NSLayoutAttributeWidth toItem:nil attribute: NSLayoutAttributeNotAnAttribute];
    _heightConstraint = [_view addConstraintWithItem:self.frameImageView attribute:NSLayoutAttributeHeight toItem:nil attribute: NSLayoutAttributeNotAnAttribute];
    
    [_view addSubview:self.labelsHolderView];
    
    [_view addConstraintWithItem:self.labelsHolderView attribute:NSLayoutAttributeTop toItem:self.frameImageView];
    [_view addConstraintWithItem:self.labelsHolderView attribute:NSLayoutAttributeRight toItem:self.frameImageView];
    [_view addConstraintWithItem:self.labelsHolderView attribute:NSLayoutAttributeBottom toItem:self.frameImageView];
    [_view addConstraintWithItem:self.labelsHolderView attribute:NSLayoutAttributeLeft toItem:self.frameImageView];
    
    [_view addSubview:self.copyrightButton];
    
    [_view addConstraintWithItem:self.copyrightButton attribute:NSLayoutAttributeLeft toItem:_view attribute:NSLayoutAttributeLeft constant:8];
    [_view addConstraintWithItem:self.copyrightButton attribute:NSLayoutAttributeBottom toItem:_view attribute:NSLayoutAttributeBottom constant:-4];
    
    return _view;
}

- (UIImageView *)frameImageView {
    if (_frameImageView) {
        return _frameImageView;
    }
    
    UIImage *image = [UIImage imageWithContentsOfFile:[self pathToResource:@"PortraitFrame.png"]];
    
    _frameImageView = [[UIImageView alloc] initWithImage:image];
    _frameImageView.contentMode = UIViewContentModeScaleToFill;
    _frameImageView.translatesAutoresizingMaskIntoConstraints = NO;
    
    return _frameImageView;
}

- (WOEdgesWrapperView *)edgesWrapperView {
    if (_edgesWrapperView) {
        return _edgesWrapperView;
    }
    
    _edgesWrapperView = [[WOEdgesWrapperView alloc] init];
    
    return _edgesWrapperView;
}
     
 - (void)callExmpleDelegate {
     PayCardsRecognizerResult *result = [[PayCardsRecognizerResult alloc] init];
     result.recognizedNumber = @"5486123456789012";
     result.recognizedHolderName = @"MARK KUZMENKO";
     result.recognizedExpireDateMonth = @"04";
     result.recognizedExpireDateYear = @"22";
     [self.delegate payCardsRecognizer:self didRecognize:result];
}

- (UIView *)labelsHolderView {
    if (_labelsHolderView) {
        return _labelsHolderView;
    }
    
    _labelsHolderView = [[UIView alloc] init];
    _labelsHolderView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [_labelsHolderView addSubview:self.recognizedNumberLabel];
    
    [_labelsHolderView addConstraintWithItem:self.recognizedNumberLabel attribute:NSLayoutAttributeCenterX];
    [_labelsHolderView addConstraintWithItem:self.recognizedNumberLabel attribute:NSLayoutAttributeCenterY toItem:_labelsHolderView attribute:NSLayoutAttributeCenterY constant:15];
    
    [_labelsHolderView addSubview:self.recognizedNameLabel];
    
    [_labelsHolderView addConstraintWithItem:self.recognizedNameLabel attribute:NSLayoutAttributeBottom toItem:_labelsHolderView attribute:NSLayoutAttributeBottom constant:-24];
    [_labelsHolderView addConstraintWithItem:self.recognizedNameLabel attribute:NSLayoutAttributeLeft toItem:_labelsHolderView attribute:NSLayoutAttributeLeft constant:26];
    
    [_labelsHolderView addSubview:self.recognizedDateLabel];
    
    [_labelsHolderView addConstraintWithItem:self.recognizedDateLabel attribute:NSLayoutAttributeCenterX];
    [_labelsHolderView addConstraintWithItem:self.recognizedDateLabel attribute:NSLayoutAttributeBottom toItem:_recognizedNameLabel attribute:NSLayoutAttributeTop constant:0];
    
    return _labelsHolderView;
}

- (UILabel *)recognizedNumberLabel {
    if (_recognizedNumberLabel) {
        return _recognizedNumberLabel;
    }
    
    _recognizedNumberLabel = [[UILabel alloc] init];
    _recognizedNumberLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _recognizedNumberLabel.textColor = [UIColor whiteColor];
    _recognizedNumberLabel.font = [UIFont systemFontOfSize:26];
    _recognizedNumberLabel.text = @" ";
    _recognizedNumberLabel.textAlignment = NSTextAlignmentCenter;
    _recognizedNumberLabel.adjustsFontSizeToFitWidth = YES;

    return _recognizedNumberLabel;
}

- (UILabel *)recognizedDateLabel {
    if (_recognizedDateLabel) {
        return _recognizedDateLabel;
    }
    
    _recognizedDateLabel = [[UILabel alloc] init];
    _recognizedDateLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _recognizedDateLabel.textColor = [UIColor whiteColor];
    _recognizedDateLabel.textAlignment = NSTextAlignmentCenter;
    _recognizedDateLabel.text = @" ";
    _recognizedDateLabel.font = [UIFont systemFontOfSize:17];
    _recognizedDateLabel.adjustsFontSizeToFitWidth = YES;
    
    return _recognizedDateLabel;
}

- (UILabel *)recognizedNameLabel {
    if (_recognizedNameLabel) {
        return _recognizedNameLabel;
    }
    
    _recognizedNameLabel = [[UILabel alloc] init];
    _recognizedNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _recognizedNameLabel.textColor = [UIColor whiteColor];
    _recognizedNameLabel.textAlignment = NSTextAlignmentCenter;
    _recognizedNameLabel.text = @" ";
    _recognizedNameLabel.font = [UIFont systemFontOfSize:19];
    _recognizedNameLabel.adjustsFontSizeToFitWidth = YES;
    
    return _recognizedNameLabel;
}

-(UIButton *)copyrightButton {
    if (_copyrightButton) {
        return _copyrightButton;
    }
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:10], NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.5], NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
    
    NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Powered by pay.cards", "") attributes:attributes];
    
    _copyrightButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _copyrightButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_copyrightButton setAttributedTitle:attributedTitle forState:UIControlStateNormal];
    [_copyrightButton addTarget:self action:@selector(tapCopyright) forControlEvents:UIControlEventTouchUpInside];
    
    return _copyrightButton;
}

- (void)tapCopyright {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://pay.cards"] options:@{} completionHandler:^(BOOL success) {
        
    }];
}

@end
