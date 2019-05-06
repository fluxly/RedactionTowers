#include "ofApp.h"

//--------------------------------------------------------------
void ofApp::setup(){
    ofSetLogLevel(OF_LOG_VERBOSE);       // OF_LOG_VERBOSE for testing, OF_LOG_SILENT for production
    ofSetLogLevel("Pd", OF_LOG_SILENT);  // see verbose info from Pd
    //ofRegisterTouchEvents(this);
    ofxAccelerometer.setup();
    //ofxiPhoneAlerts.addListener(this);
    ofSetFrameRate(30);
    ofBackgroundHex(0xfdefc2);
    //ofEnableAntiAliasing();
    
    
    // Set screen height and width
    screenH = [[UIScreen mainScreen] bounds].size.height;
    screenW = [[UIScreen mainScreen] bounds].size.width;
    background.load("background0.png");
    background.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    groundImg.load("background2.png");
    groundImg.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    cloud.load("cloudBig.png");
    for (int i=0; i<10; i++) {
        cloudX[i] = ofRandom(-500, screenW+500);
        cloudY[i] = ofRandom(-1000, screenH-50);
    }
    // For retina support
    retinaScaling = [UIScreen mainScreen].scale;
    //screenW *= retinaScaling;
    //screenH *= retinaScaling;
    ofLog(OF_LOG_VERBOSE, "SCALING %f:",retinaScaling);
    
    if (IS_IPAD) {
        device = TABLET;
    }
    
    if (device == PHONE) {
        if (retinaScaling > 1) {
            helpFont.load("slkscr.ttf", PHONE_RETINA_FONT_SIZE);
        } else {
            helpFont.load("slkscr.ttf", PHONE_FONT_SIZE);
        }
    } else {
        if (retinaScaling > 1) {
            helpFont.load("slkscr.ttf", TABLET_RETINA_FONT_SIZE);
        } else {
            helpFont.load("slkscr.ttf", TABLET_FONT_SIZE);
        }
    }
    
    ofLog(OF_LOG_VERBOSE, "Opening blocks.xml");
    if (blockDescriptions.loadFile("blocks.xml")) {
        blockDescriptions.pushTag("blocks");
        nBlocks = blockDescriptions.getNumTags("block");
        for(int i = 0; i < nBlocks; i++) {
            blockDescriptions.pushTag("block", i);
            blocks.push_back(shared_ptr<Block>(new Block));
            Block * b = blocks.back().get();
            b->physicsScale = physicsScale;
            b->n = i;
            b->w = blockDescriptions.getValue("width", 0);
            b->h = blockDescriptions.getValue("height", 0);
            b->h -= 10;
            ofLog(OF_LOG_VERBOSE, "Block %d: w:%d h:%d", b->n, b->w, b->h);
            
            blockDescriptions.popTag();
        }
    } else {
        ofLog(OF_LOG_VERBOSE, "Couldn't open blocks.xml");
    }
    ofLog(OF_LOG_VERBOSE, "Number of blocks: %d", nBlocks);
    box2d.init();
    box2d.setGravity(0, 10);
    box2d.setFPS(60);
    box2d.registerGrabbing();
    //box2d.createBounds();
    box2d.setIterations(1, 1); // minimum for IOS
    
    ground = new ofxBox2dEdge;
    ground->addVertex(-1000, ((screenH-50)/cameraScale)/physicsScale);
    ground->addVertex(2000, ((screenH-50)/cameraScale)/physicsScale);
   // ground = new ofxBox2dRect;
   // ground->setup(box2d.getWorld(), (screenW/2)/physicsScale, screenH/physicsScale-250/physicsScale, //2000, 500/cameraScale/physicsScale);
    //ground->setPhysics(1.0, 0.0, 1.0);
    ground->create(box2d.getWorld());
    
}

//--------------------------------------------------------------
void ofApp::update(){
    
    //ofVec2f gravity = ofxAccelerometer.getForce();
    //ofVec2f gravity;
    //gravity.y *= -1;
    //gravity *= 30;
    // box2d.setGravity(gravity);
    for (int i=0; i < blocks.size(); i++) {
        blocks[i].get()->update();
    }
    for (int i=0; i<10; i++) {
        cloudX[i] += ofRandom(-1, 2);
        cloudY[i] += ofRandom(-1, 2);
    }
    box2d.update();
}

//--------------------------------------------------------------
void ofApp::draw(){
    /* debug
    ofPushMatrix();
    ofScale( cameraScale*physicsScale, cameraScale*physicsScale, 1.f );
    ofSetHexColor(0xABDB44);
    for (int i=0; i < blocksOnScreen; i++) {
        blocks[i].get()->draw();
    }
    ofPopMatrix();
     */
    ofSetHexColor(0xFFFFFF);
    ofSetRectMode(OF_RECTMODE_CORNER);
    background.draw(0, 0, screenW, screenH);
    
    ofPushMatrix();
    ofTranslate(xOffset, yOffset);

    groundImg.draw(-5000, screenH-50, 10000, 50);
    ofScale( cameraScale, cameraScale, 1.f );
   /* for (int i=0; i<10; i++) {
        cloud.draw(cloudX[i], cloudY[i]);
    }*/
    
    ofSetHexColor(0xABDB44);
    for (int i=0; i < blocksOnScreen; i++) {
        blocks[i].get()->drawMe();
    }
    ofPopMatrix();
    ofSetColor(60);
    ofDrawBitmapString(blocksOnScreen, 20, screenH-40);
    ofDrawBitmapString(ofToString(ofGetFrameRate(), 0)+" fps", 80, screenH-40);

}

//--------------------------------------------------------------
void ofApp::exit(){

}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){
    if (scrollingState == 0) {
        scrollingState = -1;  // wait for move state
        ofLog(OF_LOG_VERBOSE, "Scrolling State %d", scrollingState);
        startTouchId = touch.id;
        startTouchX = (int)touch.x;
        startTouchY = (int)touch.y;
    }
}

//--------------------------------------------------------------
void ofApp::touchMoved(ofTouchEventArgs & touch){
    if ((scrollingState == -1) && (startTouchId == touch.id)) {
        if ((touch.y < (startTouchY - touchMargin * 2)) ||
            (touch.x < (startTouchX - touchMargin * 2)) ||
            (touch.y < (startTouchY - touchMargin * 2)) ||
            (touch.x > (startTouchX + touchMargin * 2 ))) {
                scrollingState = 1;
            }
        }
    // Moving with finger down: slide menu up and down
    if ((scrollingState == 1)  && (startTouchId == touch.id)) {
        xOffset += (touch.x - startTouchX)*cameraScale/10;
        yOffset += (touch.y - startTouchY)*cameraScale/10;
        if (yOffset < 0) yOffset = 0;
        ofLog(OF_LOG_VERBOSE, "Scrolling %d", yOffset);
    }
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){
    if ((scrollingState == -1) && (startTouchId == touch.id)) {
        scrollingState = 0;
        startTouchId = -1;
        startTouchX = 0;
        startTouchY = 0;
        Block * b = blocks[blocksOnScreen].get();
        b->setPhysics(1, 0 , 1);
        b->setup(box2d.getWorld(), ((touch.x-xOffset)/cameraScale)/b->physicsScale, ((touch.y - yOffset)/cameraScale)/b->physicsScale, b->w/b->physicsScale, b->h/b->physicsScale);
        b->init();
        if (blocksOnScreen < (nBlocks-1)) blocksOnScreen++;
    }
    if ((scrollingState == 1)  && (startTouchId == touch.id)) {
        scrollingState = 0;
        startTouchId = -1;
        startTouchX = 0;
        startTouchY = 0;
    }
}

//--------------------------------------------------------------
void ofApp::touchDoubleTap(ofTouchEventArgs & touch){
  /*  if (cameraScale == 0.5f) {
        cameraScale = 0.25f;
    } else {
        cameraScale = 0.5f;
    }*/
}

//--------------------------------------------------------------
void ofApp::touchCancelled(ofTouchEventArgs & touch){
    
}

//--------------------------------------------------------------
void ofApp::lostFocus(){

}

//--------------------------------------------------------------
void ofApp::gotFocus(){

}

//--------------------------------------------------------------
void ofApp::gotMemoryWarning(){

}

//--------------------------------------------------------------
void ofApp::deviceOrientationChanged(int newOrientation){

}

void ofApp::takePicture() {
    /*
     ofFbo fbo;
     ofImage img;
     
     fbo.allocate(100, 100, GL_RGBA);
     
     fbo.begin();
     ofClear(0, 255);
     ofSetColor(255);
     ofCircle(…);
     fbo.end();
     
     fbo.readToPixels(img.getTextureReference());
     img.save(“foo.png”);
     */
}
