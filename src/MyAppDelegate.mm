//
//
//

#import "MyAppDelegate.h"
#import "ofApp.h"

@implementation MyAppDelegate 

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    ofSetLogLevel(OF_LOG_VERBOSE); 
    ofLog(OF_LOG_VERBOSE, "Started App Delegate");
   
    [super applicationDidFinishLaunching:application];

    ofApp *app = new ofApp();
    self.glViewController = [[ofxiOSViewController alloc] initWithFrame:[[UIScreen mainScreen] bounds] app:app ];
    [self.window setRootViewController:self.glViewController];
    ofLog(OF_LOG_VERBOSE, "Set Orientation");
    ofOrientation requested = ofGetOrientation();
    UIInterfaceOrientation interfaceOrientation;
    interfaceOrientation = UIInterfaceOrientationPortrait;
    switch (requested) {
        case OF_ORIENTATION_DEFAULT:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_180:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_90_RIGHT:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_90_LEFT:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
        case OF_ORIENTATION_UNKNOWN:
            interfaceOrientation = UIInterfaceOrientationPortrait;
            break;
    }
    ofLog(OF_LOG_VERBOSE, "Rotate to portrait");
    [self.glViewController rotateToInterfaceOrientation:UIInterfaceOrientationPortrait animated:false];
    ofLog(OF_LOG_VERBOSE, "Set up audio stream");
    app->setupAudioStream();
    SoundOutputStream *stream = app->getSoundStream()->getSoundOutStream();
    
    return YES;
    
}

//- (void)applicationDidEnterBackground:(UIApplication *)application {
-(void)applicationDidEnterBackground:(NSNotification *)notification {
    [ofxiOSGetGLView() stopAnimation];
    glFinish();
    //only continue to generate sound when not connected to anything, maybe this needs a check for inter app audio too, but it works with garageband
}

- (void)applicationWillEnterForeground:(UIApplication *)application {

}

//check for iia connection, i had a problem with fbos not working when started from inside garageband...
-(void) checkIAACon:(int *)iaaCon{
    UInt32 connected;
    UInt32 dataSize = sizeof(UInt32);
    *iaaCon = connected;
}

//can be called from controlThread.h to test for connection
-(void) checkCon:(bool *)iaaCon{
}
-(void)applicationWillTerminate:(UIApplication *)application {
    [super applicationWillTerminate:application];
}


@end

