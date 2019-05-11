// Redaction Tower
//
// Build a tower using beautiful black blocks. Can you stack all 790? How far can you go?
//

#pragma once

#include "ofxiOS.h"
#include "ofxiOSExtras.h"
#include "ofxBox2d.h"
#include "ofxSvg.h"
#include "ofxPd.h"
#include "ofxXmlSettings.h"
#import <AVFoundation/AVFoundation.h>

//  Determine device
#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_IPHONE_5 (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 568)
#define IS_IPHONE_6 (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 667)
#define IS_IPHONE_6_PLUS (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 736)
#define IS_IPHONE_X (IS_IPHONE && [[UIScreen mainScreen] bounds].size.height == 812)
#define PHONE_FONT_SIZE (12)
#define TABLET_FONT_SIZE (24)
#define PHONE_RETINA_FONT_SIZE (18)
#define TABLET_RETINA_FONT_SIZE (24)
#define PHONE (0)
#define TABLET (1)

class Block : public ofxBox2dRect {
public:
    Block() {
    }
    int n;
    int w;
    int h;
    int x;
    int y;
    float physicsScale = 10.0f;
    int displayW;
    bool touched = false;
    int touchId = -1;
    float rotation = 0.0;
    b2BodyDef * def;
    ofxSVG * sprite;
    bool shouldPlaySound = true;
    
    void init() {
        sprite = new ofxSVG;
        ofLog(OF_LOG_VERBOSE, "Loading output%d.svg", n);
        sprite->load("output" + to_string(n) + ".svg");
    }
    
    Boolean inBounds(int x1, int y1) {
        // check id as well
        
        int x = ofxBox2dBaseShape::getPosition().x;
        int y = ofxBox2dBaseShape::getPosition().y;
        if ((x1 < (x+displayW/2)) &&
            (x1 > (x-displayW/2)) &&
            (y1 < (y+displayW/2)) &&
            (y1 > (y-displayW/2))) {
            return true;
        } else {
            return false;
        }
    }
    
    void update() {
        x = ofxBox2dBaseShape::getPosition().x * physicsScale;
        y = ofxBox2dBaseShape::getPosition().y * physicsScale;
        rotation = getRotation();
    }
    
    void drawMe() {
        if(body == NULL) {
            return;
        }
        ofPushMatrix();
        ofSetColor(255, 255, 255);
        ofTranslate(x, y);
        ofRotate(rotation, 0, 0, 1);
        ofTranslate(-w/2, -h/2);
        sprite->draw();
        ofSetHexColor(0xABDB44);
        //ofDrawRectangle(0, 0, w, h);
        ofPopMatrix();
    }
};

// a namespace for the Pd types
using namespace pd;

class ofApp : public ofxiOSApp, public PdReceiver, public PdMidiReceiver  {
	
    public:
    void setup();
    void update();
    void draw();
    void exit();
    
    void touchDown(ofTouchEventArgs &touch);
    void touchMoved(ofTouchEventArgs &touch);
    void touchUp(ofTouchEventArgs &touch);
    void touchDoubleTap(ofTouchEventArgs &touch);
    void touchCancelled(ofTouchEventArgs &touch);
    
    void lostFocus();
    void gotFocus();
    void gotMemoryWarning();
    void deviceOrientationChanged(int newOrientation);
    
    // sets the preferred sample rate, returns the *actual* samplerate
    // which may be different ie. iPhone 6S only wants 48k
    float setAVSessionSampleRate(float preferredSampleRate);
    
    // audio callbacks
    void audioReceived(float * input, int bufferSize, int nChannels);
    void audioRequested(float * output, int bufferSize, int nChannels);
    
    void helpLayerScript();
    void helpLayerDisplay(int n);
    void drawHelpString(string s, int x1, int y1, int yOffset, int row);
    
    void takePicture();
    
    ofxBox2d                box2d;
    vector <shared_ptr<Block>> blocks;
    
    int screenW;
    int screenH;
    ofImage background[8];
    ofImage groundImg;
    ofImage cameraButton;
    int cloudX[10];
    int cloudY[10];
    bool zoomedOut = false;
    
    float cameraScale = 0.5f;
    float physicsScale = 10.0f;
    ofxBox2dEdge * ground;
    //ofxBox2dRect * ground;
    int nBlocks = 0;
    int blocksOnScreen = 0;
    int scrollingState = 0;
    int startTouchId = 0;
    int startTouchX = 0;
    int startTouchY = 0;
    int touchMargin = 3;
    int prevXOffset = 0;
    int prevYOffset = 0;
    int xOffset = 0;
    int yOffset = 0;
    int device;
    int currentBackground = 0;
 
    float retinaScaling = 1.0;
    ofTrueTypeFont helpFont;
    
    ofxPd pd;
    ofxXmlSettings blockDescriptions;
    ofDirectory dir;
    ofFile file;
    string documentsDir;
    bool firstRun = true;
    bool helpOn = true;
};



