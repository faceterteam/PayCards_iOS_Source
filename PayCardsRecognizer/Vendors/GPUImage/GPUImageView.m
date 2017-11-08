#import "GPUImageView.h"
#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>
#import "GPUImageContext.h"
#import "GPUImageFilter.h"
#import <AVFoundation/AVFoundation.h>

#pragma mark -
#pragma mark Private methods and instance variables

@interface GPUImageView () 
{
    GPUImageFramebuffer *inputFramebufferForDisplay;
    GLuint displayRenderbuffer, displayFramebuffer;
    
    GLProgram *displayProgram;
    GLint displayPositionAttribute, displayTextureCoordinateAttribute;
    GLint displayInputTextureUniform;

    CGSize inputImageSize;
    GLfloat imageVertices[8];
    GLfloat backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha;

    CGSize boundsSizeAtFrameBufferEpoch;
}

@property (assign, nonatomic) NSUInteger aspectRatio;

// Initialization and teardown
- (void)commonInit;

// Managing the display FBOs
- (void)createDisplayFramebuffer;
- (void)destroyDisplayFramebuffer;

// Handling fill mode
- (void)recalculateViewGeometry;

@end

@implementation GPUImageView

@synthesize aspectRatio;
@synthesize sizeInPixels = _sizeInPixels;
@synthesize fillMode = _fillMode;
@synthesize enabled;

#pragma mark -
#pragma mark Initialization and teardown

+ (Class)layerClass 
{
	return [CAEAGLLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame]))
    {
		return nil;
    }
    [self commonInit];
    
    return self;
}

-(id)initWithCoder:(NSCoder *)coder
{
	if (!(self = [super initWithCoder:coder])) 
    {
        return nil;
	}
    [self commonInit];

	return self;
}

//-(UIImage*)imageFromGPUView:(CGRect)rect
//{
//    GLint backingWidth2, backingHeight2;
//    //Bind the color renderbuffer used to render the OpenGL ES view
//    // If your application only creates a single color renderbuffer which is already bound at this point,
//    // this call is redundant, but it is needed if you're dealing with multiple renderbuffers.
//    // Note, replace "_colorRenderbuffer" with the actual name of the renderbuffer object defined in your class.
//    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
//    
//    // Get the size of the backing CAEAGLLayer
//    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth2);
//    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight2);
//    
//    NSInteger x = 0, y = 0, width2 = backingWidth2, height2 = backingHeight2;
//    NSInteger dataLength = width2 * height2 * 4;
//    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
//    
//    // Read pixel data from the framebuffer
//    glPixelStorei(GL_PACK_ALIGNMENT, 4);
//    glReadPixels(x, y, width2, height2, GL_RGBA, GL_UNSIGNED_BYTE, data);
//    
//    // Create a CGImage with the pixel data
//    // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
//    // otherwise, use kCGImageAlphaPremultipliedLast
//    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
//    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
//    CGImageRef iref = CGImageCreate(width2, height2, 8, 32, width2 * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
//                                    ref, NULL, true, kCGRenderingIntentDefault);
//    
//    // OpenGL ES measures data in PIXELS
//    // Create a graphics context with the target size measured in POINTS
//    NSInteger widthInPoints, heightInPoints;
//    if (NULL != UIGraphicsBeginImageContextWithOptions) {
//        // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
//        // Set the scale parameter to your OpenGL ES view's contentScaleFactor
//        // so that you get a high-resolution snapshot when its value is greater than 1.0
//        CGFloat scale = self.contentScaleFactor;
//        widthInPoints = width2 / scale;
//        heightInPoints = height2 / scale;
//        UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthInPoints, heightInPoints), NO, scale);
//    }
//    else {
//        // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
//        widthInPoints = width2;
//        heightInPoints = height2;
//        UIGraphicsBeginImageContext(CGSizeMake(widthInPoints, heightInPoints));
//    }
//    
//    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
//    
//    // UIKit coordinate system is upside down to GL/Quartz coordinate system
//    // Flip the CGImage by rendering it to the flipped bitmap context
//    // The size of the destination area is measured in POINTS
//    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
//    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, widthInPoints, heightInPoints), iref);
//    
//    // Retrieve the UIImage from the current context
//    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
//    
//    UIGraphicsEndImageContext();
//    
//    // Clean up
//    free(data);
//    CFRelease(ref);
//    CFRelease(colorspace);
//    CGImageRelease(iref);
//    
//    return image;
//}


- (void)commonInit;
{
    // Set scaling to account for Retina display	
    if ([self respondsToSelector:@selector(setContentScaleFactor:)])
    {
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
    }

    inputRotation = kGPUImageNoRotation;
    self.opaque = YES;
    self.hidden = NO;
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    eaglLayer.opaque = YES;
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];

    self.enabled = YES;
    
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];
        
        displayProgram = [[GPUImageContext sharedImageProcessingContext] programForVertexShaderString:kGPUImageVertexShaderString fragmentShaderString:kGPUImagePassthroughFragmentShaderString];
        if (!displayProgram.initialized)
        {
            [displayProgram addAttribute:@"position"];
            [displayProgram addAttribute:@"inputTextureCoordinate"];
            
            if (![displayProgram link])
            {
                NSString *progLog = [displayProgram programLog];
                NSLog(@"Program link log: %@", progLog);
                NSString *fragLog = [displayProgram fragmentShaderLog];
                NSLog(@"Fragment shader compile log: %@", fragLog);
                NSString *vertLog = [displayProgram vertexShaderLog];
                NSLog(@"Vertex shader compile log: %@", vertLog);
                displayProgram = nil;
                NSAssert(NO, @"Filter shader link failed");
            }
        }
        
        displayPositionAttribute = [displayProgram attributeIndex:@"position"];
        displayTextureCoordinateAttribute = [displayProgram attributeIndex:@"inputTextureCoordinate"];
        displayInputTextureUniform = [displayProgram uniformIndex:@"inputImageTexture"]; // This does assume a name of "inputTexture" for the fragment shader

        [GPUImageContext setActiveShaderProgram:displayProgram];
        glEnableVertexAttribArray(displayPositionAttribute);
        glEnableVertexAttribArray(displayTextureCoordinateAttribute);
        
        [self setBackgroundColorRed:0.0 green:0.0 blue:0.0 alpha:1.0];
        _fillMode = kGPUImageFillModePreserveAspectRatio;
        [self createDisplayFramebuffer];
    });
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // The frame buffer needs to be trashed and re-created when the view size changes.
    if (!CGSizeEqualToSize(self.bounds.size, boundsSizeAtFrameBufferEpoch) &&
        !CGSizeEqualToSize(self.bounds.size, CGSizeZero)) {
        runSynchronouslyOnVideoProcessingQueue(^{
            [self destroyDisplayFramebuffer];
            [self createDisplayFramebuffer];
            [self recalculateViewGeometry];
        });
    }
}

- (void)dealloc
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [self destroyDisplayFramebuffer];
    });
}

#pragma mark -
#pragma mark Managing the display FBOs

- (void)createDisplayFramebuffer;
{
    [GPUImageContext useImageProcessingContext];
    
    glGenFramebuffers(1, &displayFramebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
	
    glGenRenderbuffers(1, &displayRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
	
    [[[GPUImageContext sharedImageProcessingContext] context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
	
    GLint backingWidth, backingHeight;

    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    
    if ( (backingWidth == 0) || (backingHeight == 0) )
    {
        [self destroyDisplayFramebuffer];
        return;
    }
    
    _sizeInPixels.width = (CGFloat)backingWidth;
    _sizeInPixels.height = (CGFloat)backingHeight;

//    NSLog(@"Backing width: %d, height: %d", backingWidth, backingHeight);

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, displayRenderbuffer);
	
    GLuint framebufferCreationStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    NSAssert(framebufferCreationStatus == GL_FRAMEBUFFER_COMPLETE, @"Failure with display framebuffer generation for display of size: %f, %f", self.bounds.size.width, self.bounds.size.height);
    boundsSizeAtFrameBufferEpoch = self.bounds.size;
}

- (void)destroyDisplayFramebuffer;
{
    [GPUImageContext useImageProcessingContext];

    if (displayFramebuffer)
	{
		glDeleteFramebuffers(1, &displayFramebuffer);
		displayFramebuffer = 0;
	}
	
	if (displayRenderbuffer)
	{
		glDeleteRenderbuffers(1, &displayRenderbuffer);
		displayRenderbuffer = 0;
	}
}

- (void)setDisplayFramebuffer;
{
    if (!displayFramebuffer)
    {
        [self createDisplayFramebuffer];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, displayFramebuffer);
    
    glViewport(0, 0, (GLint)_sizeInPixels.width, (GLint)_sizeInPixels.height);
}

- (void)presentFramebuffer;
{
    glBindRenderbuffer(GL_RENDERBUFFER, displayRenderbuffer);
    [[GPUImageContext sharedImageProcessingContext] presentBufferForDisplay];
}

#pragma mark -
#pragma mark Handling fill mode

- (void)recalculateViewGeometry;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            CGFloat heightScaling, widthScaling;
            
            CGSize currentViewSize = self.bounds.size;
            
            //    CGFloat imageAspectRatio = inputImageSize.width / inputImageSize.height;
            //    CGFloat viewAspectRatio = currentViewSize.width / currentViewSize.height;
            
            CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(inputImageSize, self.bounds);
            
            switch(_fillMode)
            {
                    case kGPUImageFillModeStretch:
                {
                    widthScaling = 1.0;
                    heightScaling = 1.0;
                }; break;
                    case kGPUImageFillModePreserveAspectRatio:
                {
                    widthScaling = insetRect.size.width / currentViewSize.width;
                    heightScaling = insetRect.size.height / currentViewSize.height;
                }; break;
                    case kGPUImageFillModePreserveAspectRatioAndFill:
                {
                    //            CGFloat widthHolder = insetRect.size.width / currentViewSize.width;
                    widthScaling = currentViewSize.height / insetRect.size.height;
                    heightScaling = currentViewSize.width / insetRect.size.width;
                }; break;
            }
            
            imageVertices[0] = -widthScaling;
            imageVertices[1] = -heightScaling;
            imageVertices[2] = widthScaling;
            imageVertices[3] = -heightScaling;
            imageVertices[4] = -widthScaling;
            imageVertices[5] = heightScaling;
            imageVertices[6] = widthScaling;
            imageVertices[7] = heightScaling;
        });

    });
    
//    static const GLfloat imageVertices[] = {
//        -1.0f, -1.0f,
//        1.0f, -1.0f,
//        -1.0f,  1.0f,
//        1.0f,  1.0f,
//    };
}

- (void)setBackgroundColorRed:(GLfloat)redComponent green:(GLfloat)greenComponent blue:(GLfloat)blueComponent alpha:(GLfloat)alphaComponent;
{
    backgroundColorRed = redComponent;
    backgroundColorGreen = greenComponent;
    backgroundColorBlue = blueComponent;
    backgroundColorAlpha = alphaComponent;
}

+ (const GLfloat *)textureCoordinatesForRotation:(GPUImageRotationMode)rotationMode;
{
//    static const GLfloat noRotationTextureCoordinates[] = {
//        0.0f, 0.0f,
//        1.0f, 0.0f,
//        0.0f, 1.0f,
//        1.0f, 1.0f,
//    };
    
    static const GLfloat noRotationTextureCoordinates[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };

    static const GLfloat rotateRightTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };

    static const GLfloat rotateLeftTextureCoordinates[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
        
    static const GLfloat verticalFlipTextureCoordinates[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat horizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateRightVerticalFlipTextureCoordinates[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlipTextureCoordinates[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };

    static const GLfloat rotate180TextureCoordinates[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    switch(rotationMode)
    {
        case kGPUImageNoRotation: return noRotationTextureCoordinates;
        case kGPUImageRotateLeft: return rotateLeftTextureCoordinates;
        case kGPUImageRotateRight: return rotateRightTextureCoordinates;
        case kGPUImageFlipVertical: return verticalFlipTextureCoordinates;
        case kGPUImageFlipHorizonal: return horizontalFlipTextureCoordinates;
        case kGPUImageRotateRightFlipVertical: return rotateRightVerticalFlipTextureCoordinates;
        case kGPUImageRotateRightFlipHorizontal: return rotateRightHorizontalFlipTextureCoordinates;
        case kGPUImageRotate180: return rotate180TextureCoordinates;
    }
}

#pragma mark -
#pragma mark GPUInput protocol

- (void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext setActiveShaderProgram:displayProgram];
        [self setDisplayFramebuffer];
        
        glClearColor(backgroundColorRed, backgroundColorGreen, backgroundColorBlue, backgroundColorAlpha);
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        
        glActiveTexture(GL_TEXTURE4);
        glBindTexture(GL_TEXTURE_2D, [inputFramebufferForDisplay texture]);
        glUniform1i(displayInputTextureUniform, 4);
        
        glVertexAttribPointer(displayPositionAttribute, 2, GL_FLOAT, 0, 0, imageVertices);
        glVertexAttribPointer(displayTextureCoordinateAttribute, 2, GL_FLOAT, 0, 0, [GPUImageView textureCoordinatesForRotation:inputRotation]);
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        [self presentFramebuffer];
        [inputFramebufferForDisplay unlock];
        inputFramebufferForDisplay = nil;
    });
}

- (NSInteger)nextAvailableTextureIndex;
{
    return 0;
}

- (void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex;
{
    inputFramebufferForDisplay = newInputFramebuffer;
    [inputFramebufferForDisplay lock];
}

- (void)setInputRotation:(GPUImageRotationMode)newInputRotation atIndex:(NSInteger)textureIndex;
{
    inputRotation = newInputRotation;
}

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        CGSize rotatedSize = newSize;
        
        if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
        {
            rotatedSize.width = newSize.height;
            rotatedSize.height = newSize.width;
        }
        
        if (!CGSizeEqualToSize(inputImageSize, rotatedSize))
        {
            inputImageSize = rotatedSize;
            [self recalculateViewGeometry];
        }
    });
}

- (CGSize)maximumOutputSize;
{
    if ([self respondsToSelector:@selector(setContentScaleFactor:)])
    {
        CGSize pointSize = self.bounds.size;
        return CGSizeMake(self.contentScaleFactor * pointSize.width, self.contentScaleFactor * pointSize.height);
    }
    else
    {
        return self.bounds.size;
    }
}

- (void)endProcessing
{
}

- (BOOL)shouldIgnoreUpdatesToThisTarget;
{
    return NO;
}

- (BOOL)wantsMonochromeInput;
{
    return NO;
}

- (void)setCurrentlyReceivingMonochromeInput:(BOOL)newValue;
{
    
}

#pragma mark -
#pragma mark Accessors

- (CGSize)sizeInPixels;
{
    if (CGSizeEqualToSize(_sizeInPixels, CGSizeZero))
    {
        return [self maximumOutputSize];
    }
    else
    {
        return _sizeInPixels;
    }
}

- (void)setFillMode:(GPUImageFillModeType)newValue;
{
    _fillMode = newValue;
    [self recalculateViewGeometry];
}

@end
