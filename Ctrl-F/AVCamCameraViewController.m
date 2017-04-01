/*
  Copyright (C) 2016 Apple Inc. All Rights Reserved.
  See LICENSE.txt for this sample’s licensing information
	
  Abstract:
  View controller for camera interface.
*/

@import AVFoundation;

#import "AVCamCameraViewController.h"
#import "AVCamPreviewView.h"

static void * SessionRunningContext = &SessionRunningContext;

typedef NS_ENUM( NSInteger, AVCamSetupResult ) {
    AVCamSetupResultSuccess,
	AVCamSetupResultCameraNotAuthorized,
	AVCamSetupResultSessionConfigurationFailed
        };

@interface AVCaptureDeviceDiscoverySession (Utilities)

- (NSInteger)uniqueDevicePositionsCount;

@end

@implementation AVCaptureDeviceDiscoverySession (Utilities)

- (NSInteger)uniqueDevicePositionsCount
{
    NSMutableArray<NSNumber *> *uniqueDevicePositions = [NSMutableArray array];
	
    for ( AVCaptureDevice *device in self.devices ) {
        if ( ! [uniqueDevicePositions containsObject:@(device.position)] ) {
            [uniqueDevicePositions addObject:@(device.position)];
        }
    }
	
    return uniqueDevicePositions.count;
}

@end

@interface AVCamCameraViewController ()

// Session management.
@property (nonatomic, weak) IBOutlet AVCamPreviewView *previewView;
@property (nonatomic, weak) IBOutlet UISegmentedControl *captureModeControl;

@property (nonatomic) AVCamSetupResult setupResult;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;

// Device configuration.
@property (nonatomic, weak) IBOutlet UIButton *cameraButton;
@property (nonatomic, weak) IBOutlet UILabel *cameraUnavailableLabel;
@property (nonatomic) AVCaptureDeviceDiscoverySession *videoDeviceDiscoverySession;

// Recording movies.
@property (nonatomic, weak) IBOutlet UIButton *resumeButton;

@end

@implementation AVCamCameraViewController

#pragma mark View Controller Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    // Disable UI. The UI is enabled if and only if the session starts running.
    self.cameraButton.enabled = NO;
    self.captureModeControl.enabled = NO;
	
    // Create the AVCaptureSession.
    self.session = [[AVCaptureSession alloc] init];
	
    // Create a device discovery session.
    NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeBuiltInWideAngleCamera, AVCaptureDeviceTypeBuiltInDuoCamera];
    self.videoDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
	
    // Set up the preview view.
    self.previewView.session = self.session;
	
    // Communicate with the session and other session objects on this queue.
    self.sessionQueue = dispatch_queue_create( "session queue", DISPATCH_QUEUE_SERIAL );
	
    self.setupResult = AVCamSetupResultSuccess;
	
    /*
      Check video authorization status. Video access is required and audio
      access is optional. If audio access is denied, audio is not recorded
      during movie recording.
    */
    switch ( [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] )
    {
        case AVAuthorizationStatusAuthorized:
        {
            // The user has previously granted access to the camera.
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            /*
              The user has not yet been presented with the option to grant
              video access. We suspend the session queue to delay session
              setup until the access request has completed.
				
              Note that audio access will be implicitly requested when we
              create an AVCaptureDeviceInput for audio during session setup.
            */
            dispatch_suspend( self.sessionQueue );
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^( BOOL granted ) {
                    if ( ! granted ) {
                        self.setupResult = AVCamSetupResultCameraNotAuthorized;
                    }
                    dispatch_resume( self.sessionQueue );
                }];
            break;
        }
        default:
        {
            // The user has previously denied access.
            self.setupResult = AVCamSetupResultCameraNotAuthorized;
            break;
        }
    }
    
    /*
      Setup the capture session.
      In general it is not safe to mutate an AVCaptureSession or any of its
      inputs, outputs, or connections from multiple threads at the same time.
		
      Why not do all of this on the main queue?
      Because -[AVCaptureSession startRunning] is a blocking call which can
      take a long time. We dispatch session setup to the sessionQueue so
      that the main queue isn't blocked, which keeps the UI responsive.
    */
    dispatch_async( self.sessionQueue, ^{
            [self configureSession];
	} );
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
	
    dispatch_async( self.sessionQueue, ^{
            switch ( self.setupResult )
            {
                case AVCamSetupResultSuccess:
                {
                    // Only setup observers and start the session running if setup succeeded.
                    [self addObservers];
                    [self.session startRunning];
                    self.sessionRunning = self.session.isRunning;
                    break;
                }
                case AVCamSetupResultCameraNotAuthorized:
                {
                    dispatch_async( dispatch_get_main_queue(), ^{
                            NSString *message = NSLocalizedString( @"AVCam doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );
                            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                            [alertController addAction:cancelAction];
                            // Provide quick access to Settings.
                            UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"Settings", @"Alert button to open Settings" ) style:UIAlertActionStyleDefault handler:^( UIAlertAction *action ) {
                                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
                                }];
                            [alertController addAction:settingsAction];
                            [self presentViewController:alertController animated:YES completion:nil];
                        } );
                    break;
                }
                case AVCamSetupResultSessionConfigurationFailed:
                {
                    dispatch_async( dispatch_get_main_queue(), ^{
                            NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );
                            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                            [alertController addAction:cancelAction];
                            [self presentViewController:alertController animated:YES completion:nil];
                        } );
                    break;
                }
            }
        } );
}

- (void)viewDidDisappear:(BOOL)animated
{
    dispatch_async( self.sessionQueue, ^{
            if ( self.setupResult == AVCamSetupResultSuccess ) {
                [self.session stopRunning];
                [self removeObservers];
            }
	} );
	
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotate
{
    return true;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
	
    if ( UIDeviceOrientationIsPortrait( deviceOrientation ) || UIDeviceOrientationIsLandscape( deviceOrientation ) ) {
        self.previewView.videoPreviewLayer.connection.videoOrientation = (AVCaptureVideoOrientation)deviceOrientation;
    }
}

#pragma mark Session Management

// Call this on the session queue.
- (void)configureSession
{
    if ( self.setupResult != AVCamSetupResultSuccess ) {
        return;
    }
	
    NSError *error = nil;
	
    [self.session beginConfiguration];
    
    // Add video input.
	
    // Choose the back dual camera if available, otherwise default to a wide angle camera.
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDuoCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    if ( ! videoDevice ) {
        // If the back dual camera is not available, default to the back wide angle camera.
        videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
		
        // In some cases where users break their phones, the back wide angle camera is not available. In this case, we should default to the front wide angle camera.
        if ( ! videoDevice ) {
            videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        }
    }
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if ( ! videoDeviceInput ) {
        NSLog( @"Could not create video device input: %@", error );
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    if ( [self.session canAddInput:videoDeviceInput] ) {
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
		
        dispatch_async( dispatch_get_main_queue(), ^{
                /*
                  Why are we dispatching this to the main queue?
                  Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView
                  can only be manipulated on the main thread.
                  Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                  on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
				
                  Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
                  handled by -[AVCamCameraViewController viewWillTransitionToSize:withTransitionCoordinator:].
                */
                UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
                AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
                if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
                    initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
                }
			
                self.previewView.videoPreviewLayer.connection.videoOrientation = initialVideoOrientation;
            } );
    }
    else {
        NSLog( @"Could not add video device input to the session" );
        self.setupResult = AVCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    
    [self.session commitConfiguration];
}

- (IBAction)resumeInterruptedSession:(id)sender
{
    dispatch_async( self.sessionQueue, ^{
            /*
              The session might fail to start running, e.g., if a phone or FaceTime call is still
              using audio or video. A failure to start the session running will be communicated via
              a session runtime error notification. To avoid repeatedly failing to start the session
              running, we only try to restart the session running in the session runtime error handler
              if we aren't trying to resume the session running.
            */
            [self.session startRunning];
            self.sessionRunning = self.session.isRunning;
            if ( ! self.session.isRunning ) {
                dispatch_async( dispatch_get_main_queue(), ^{
                        NSString *message = NSLocalizedString( @"Unable to resume", @"Alert message when unable to resume the session running" );
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"AVCam" message:message preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString( @"OK", @"Alert OK button" ) style:UIAlertActionStyleCancel handler:nil];
                        [alertController addAction:cancelAction];
                        [self presentViewController:alertController animated:YES completion:nil];
                    } );
            }
            else {
                dispatch_async( dispatch_get_main_queue(), ^{
                        self.resumeButton.hidden = YES;
                    } );
            }
	} );
}

#pragma mark Device Configuration

- (IBAction)changeCamera:(id)sender
{
    self.cameraButton.enabled = NO;
    self.captureModeControl.enabled = NO;
	
    dispatch_async( self.sessionQueue, ^{
            AVCaptureDevice *currentVideoDevice = self.videoDeviceInput.device;
            AVCaptureDevicePosition currentPosition = currentVideoDevice.position;
		
            AVCaptureDevicePosition preferredPosition;
            AVCaptureDeviceType preferredDeviceType;
		
            switch ( currentPosition )
            {
                case AVCaptureDevicePositionUnspecified:
                case AVCaptureDevicePositionFront:
                    preferredPosition = AVCaptureDevicePositionBack;
                    preferredDeviceType = AVCaptureDeviceTypeBuiltInDuoCamera;
                    break;
                case AVCaptureDevicePositionBack:
                    preferredPosition = AVCaptureDevicePositionFront;
                    preferredDeviceType = AVCaptureDeviceTypeBuiltInWideAngleCamera;
                    break;
            }
		
            NSArray<AVCaptureDevice *> *devices = self.videoDeviceDiscoverySession.devices;
            AVCaptureDevice *newVideoDevice = nil;
		
            // First, look for a device with both the preferred position and device type.
            for ( AVCaptureDevice *device in devices ) {
                if ( device.position == preferredPosition && [device.deviceType isEqualToString:preferredDeviceType] ) {
                    newVideoDevice = device;
                    break;
                }
            }
		
            // Otherwise, look for a device with only the preferred position.
            if ( ! newVideoDevice ) {
                for ( AVCaptureDevice *device in devices ) {
                    if ( device.position == preferredPosition ) {
                        newVideoDevice = device;
                        break;
                    }
                }
            }
		
            if ( newVideoDevice ) {
                AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newVideoDevice error:NULL];
			
                [self.session beginConfiguration];
			
                // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
                [self.session removeInput:self.videoDeviceInput];
			
                if ( [self.session canAddInput:videoDeviceInput] ) {
                    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
				
                    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:newVideoDevice];
				
                    [self.session addInput:videoDeviceInput];
                    self.videoDeviceInput = videoDeviceInput;
                }
                else {
                    [self.session addInput:self.videoDeviceInput];
                }
                
                [self.session commitConfiguration];
            }
            
            dispatch_async( dispatch_get_main_queue(), ^{
                    self.cameraButton.enabled = YES;
                    self.captureModeControl.enabled = YES;
		} );
	} );
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint devicePoint = [self.previewView.videoPreviewLayer captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:gestureRecognizer.view]];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async( self.sessionQueue, ^{
            AVCaptureDevice *device = self.videoDeviceInput.device;
            NSError *error = nil;
            if ( [device lockForConfiguration:&error] ) {
                /*
                  Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                  Call set(Focus/Exposure)Mode() to apply the new point of interest.
                */
                if ( device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode] ) {
                    device.focusPointOfInterest = point;
                    device.focusMode = focusMode;
                }
			
                if ( device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode] ) {
                    device.exposurePointOfInterest = point;
                    device.exposureMode = exposureMode;
                }
			
                device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
                [device unlockForConfiguration];
            }
            else {
                NSLog( @"Could not lock device for configuration: %@", error );
            }
	} );
}

#pragma mark KVO and Notifications

- (void)addObservers
{
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDeviceInput.device];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
	
    /*
      A session can only run when the app is full screen. It will be interrupted
      in a multi-app layout, introduced in iOS 9, see also the documentation of
      AVCaptureSessionInterruptionReason. Add observers to handle these session
      interruptions and show a preview is paused message. See the documentation
      of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
    */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == SessionRunningContext ) {
        BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
        
        dispatch_async( dispatch_get_main_queue(), ^{
                // Only enable the ability to change camera if the device has more than one camera.
                self.cameraButton.enabled = isSessionRunning && ( self.videoDeviceDiscoverySession.uniqueDevicePositionsCount > 1 );
            } );
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake( 0.5, 0.5 );
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)sessionRuntimeError:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog( @"Capture session runtime error: %@", error );
	
    /*
      Automatically try to restart the session running if media services were
      reset and the last start running succeeded. Otherwise, enable the user
      to try to resume the session running.
    */
    if ( error.code == AVErrorMediaServicesWereReset ) {
        dispatch_async( self.sessionQueue, ^{
                if ( self.isSessionRunning ) {
                    [self.session startRunning];
                    self.sessionRunning = self.session.isRunning;
                }
                else {
                    dispatch_async( dispatch_get_main_queue(), ^{
                            self.resumeButton.hidden = NO;
                        } );
                }
            } );
    }
    else {
        self.resumeButton.hidden = NO;
    }
}

- (void)sessionWasInterrupted:(NSNotification *)notification
{
    /*
      In some scenarios we want to enable the user to resume the session running.
      For example, if music playback is initiated via control center while
      using AVCam, then the user can let AVCam resume
      the session running, which will stop music playback. Note that stopping
      music playback in control center will not automatically resume the session
      running. Also note that it is not always possible to resume, see -[resumeInterruptedSession:].
    */
    BOOL showResumeButton = NO;
	
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    NSLog( @"Capture session was interrupted with reason %ld", (long)reason );
	
    if ( reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
         reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient ) {
        showResumeButton = YES;
    }
    else if ( reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps ) {
        // Simply fade-in a label to inform the user that the camera is unavailable.
        self.cameraUnavailableLabel.alpha = 0.0;
        self.cameraUnavailableLabel.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
                self.cameraUnavailableLabel.alpha = 1.0;
            }];
    }
	
    if ( showResumeButton ) {
        // Simply fade-in a button to enable the user to try to resume the session running.
        self.resumeButton.alpha = 0.0;
        self.resumeButton.hidden = NO;
        [UIView animateWithDuration:0.25 animations:^{
                self.resumeButton.alpha = 1.0;
            }];
    }
}

- (void)sessionInterruptionEnded:(NSNotification *)notification
{
    NSLog( @"Capture session interruption ended" );
	
    if ( ! self.resumeButton.hidden ) {
        [UIView animateWithDuration:0.25 animations:^{
                self.resumeButton.alpha = 0.0;
            } completion:^( BOOL finished ) {
                self.resumeButton.hidden = YES;
            }];
    }
    if ( ! self.cameraUnavailableLabel.hidden ) {
        [UIView animateWithDuration:0.25 animations:^{
                self.cameraUnavailableLabel.alpha = 0.0;
            } completion:^( BOOL finished ) {
                self.cameraUnavailableLabel.hidden = YES;
            }];
    }
}

@end
