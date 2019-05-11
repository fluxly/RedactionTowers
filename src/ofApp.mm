#include "ofApp.h"

extern "C" {
    void freeverb_tilde_setup();
}

//--------------------------------------------------------------
void ofApp::setup(){
    ofSetLogLevel(OF_LOG_VERBOSE);       // OF_LOG_VERBOSE for testing, OF_LOG_SILENT for production
    ofSetLogLevel("Pd", OF_LOG_VERBOSE);  // see verbose info from Pd
    //ofRegisterTouchEvents(this);
    ofxAccelerometer.setup();
    ofxiPhoneAlerts.addListener(this);
    ofSetFrameRate(30);
    ofBackgroundHex(0xfdefc2);
    
    // try to set the preferred iOS sample rate, but get the actual sample rate
    // being used by the AVSession since newer devices like the iPhone 6S only
    // want specific values (ie 48000 instead of 44100)
    float sampleRate = setAVSessionSampleRate(44100);
    
    // the number if libpd ticks per buffer,
    // used to compute the audio buffer len: tpb * blocksize (always 64)
    int ticksPerBuffer = 8; // 8 * 64 = buffer len of 512
    
    // setup OF sound stream using the current *actual* samplerate
    /*ofSoundStreamSettings settings;
     settings.numInputChannels = 1;
     settings.numOutputChannels = 2;
     settings.sampleRate = sampleRate;
     settings.bufferSize = ofxPd::blockSize() * ticksPerBuffer;
     settings.setInListener(this);
     settings.setOutListener(this);*/
    ofSoundStreamSetup(2, 0, sampleRate, ofxPd::blockSize() * ticksPerBuffer, 2);
    
    // setup Pd
    //
    // set 4th arg to true for queued message passing using an internal ringbuffer,
    // this is useful if you need to control where and when the message callbacks
    // happen (ie. within a GUI thread)
    //
    // note: you won't see any message prints until update() is called since
    // the queued messages are processed there, this is normal
    //
    if(!pd.init(2, 0, sampleRate, ticksPerBuffer-1, false)) {
        OF_EXIT_APP(1);
    }
    
    //midiChan = 1; // midi channels are 1-16
    
    // subscribe to receive source names
    pd.subscribe("toOF");
    pd.subscribe("env");
    
    // add message receiver, required if you want to receieve messages
    pd.addReceiver(*this);   // automatically receives from all subscribed sources
    pd.ignoreSource(*this, "env");      // don't receive from "env"
    //pd.ignoreSource(*this);           // ignore all sources
    //pd.receiveSource(*this, "toOF");  // receive only from "toOF"
    
    // add midi receiver, required if you want to recieve midi messages
    pd.addMidiReceiver(*this);  // automatically receives from all channels
    //pd.ignoreMidiChannel(*this, 1);     // ignore midi channel 1
    //pd.ignoreMidiChannel(*this);        // ignore all channels
    //pd.receiveMidiChannel(*this, 1);    // receive only from channel 1
    
    // add the data/pd folder to the search path
    //pd.addToSearchPath("pd/abs");
    
    // audio processing on
    pd.start();
    
    // Setup externals
    freeverb_tilde_setup();
    
    // -----------------------------------------------------
    cout << endl << "BEGIN Patch Test" << endl;
    
    // open patch
    Patch patch = pd.openPatch("wind4.pd");
    cout << patch << endl;
    
    // close patch
    pd.closePatch(patch);
    cout << patch << endl;
    
    // open patch again
    patch = pd.openPatch(patch);
    cout << patch << endl;
    
    cout << "FINISH Patch Test" << endl;
    
    //ofEnableAntiAliasing();
    documentsDir = ofxiOSGetDocumentsDirectory();

    // Set screen height and width
    screenH = [[UIScreen mainScreen] bounds].size.height;
    screenW = [[UIScreen mainScreen] bounds].size.width;
    for (int i=0; i<8; i++) {
        //background[i].load("background"+to_string(i)+".png");
        background[i].load("background0.png");
        background[i].getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    }
    currentBackground = (int)ofRandom(0, 7);
    groundImg.load("background2.png");
    groundImg.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    cameraButton.load("cameraIcon.png");
    //cameraButton.getTexture().setTextureMinMagFilter(GL_NEAREST,GL_NEAREST);
    
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
    
    dir.open(ofxiOSGetDocumentsDirectory());
    int numFiles = dir.listDir();
    firstRun = true;
    
    for (int i=0; i<numFiles; ++i) {
        if (dir.getName(i) == "blocks.xml") {
            firstRun = false;
            helpOn = false;        // turn off help layer if not first run
        }
        //cout << "Path at index " << i << " = " << dir.getName(i) << endl;
    }
    if (firstRun) {
        // ofLog(OF_LOG_VERBOSE, "First Run: copies files to documents from bundle.");
        file.copyFromTo("blocks.xml", ofxiOSGetDocumentsDirectory()+"blocks.xml", true, true);
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
    //box2d.registerGrabbing();
    //box2d.createBounds();
    box2d.setIterations(1, 1); // minimum for IOS
    
    ground = new ofxBox2dEdge;
    ground->addVertex(-2000, ((screenH-50)/cameraScale)/physicsScale);
    ground->addVertex(3500, ((screenH-50)/cameraScale)/physicsScale);
    ground->create(box2d.getWorld());
    //ground = new ofxBox2dRect;
    //ground->setup(box2d.getWorld(), (screenW/2)/physicsScale, screenH/physicsScale-250/physicsScale, 2000, 500/cameraScale/physicsScale);
    //ground->setPhysics(0.0, 0.0, 1.0);
   
    
}

//--------------------------------------------------------------
void ofApp::update(){
    if(pd.isQueued()) {
        // process any received messages, if you're using the queue and *do not*
        // call these, you won't receieve any messages or midi!
        pd.receiveMessages();
        pd.receiveMidi();
    }
    //ofVec2f gravity = ofxAccelerometer.getForce();
    //ofVec2f gravity;
    //gravity.y *= -1;
    //gravity *= 30;
    // box2d.setGravity(gravity);
    for (int i=0; i < blocks.size(); i++) {
        blocks[i].get()->update();
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
    background[currentBackground].draw(0, 0, screenW, screenH);
    
    ofPushMatrix();
    ofTranslate(xOffset, yOffset);

    groundImg.draw(-5000, screenH-50, 10000, 50);
    ofScale( cameraScale, cameraScale, 1.f );

    
    ofSetHexColor(0xABDB44);
    for (int i=0; i < blocksOnScreen; i++) {
        blocks[i].get()->drawMe();
    }
    ofPopMatrix();
    ofSetColor(60);
    ofSetHexColor(0xfdefc2);
    ofDrawRectangle(0, screenH-helpFont.getSize()-7, screenW, screenH);
    ofSetHexColor(0x333333);
    helpFont.drawString(to_string(blocksOnScreen) + "/790" , 20, screenH-5);
    if (zoomedOut) {
        helpFont.drawString("+" , screenW/2-helpFont.stringWidth("-")/2, screenH-5);
    } else {
        helpFont.drawString("-" , screenW/2-helpFont.stringWidth("+")/2, screenH-5);
    }
    ofSetHexColor(0xffffff);
    cameraButton.draw(screenW-25*retinaScaling, screenH-14*retinaScaling, 15*retinaScaling, 12.5*retinaScaling);
    //ofDrawBitmapString(ofToString(ofGetFrameRate(), 0)+" fps", 80, screenH-40);
}

void ofApp::helpLayerDisplay(int n) {
    ofSetColor(0, 0, 0);
    switch (n) {
        case -1:
            break;
        case 0:
            drawHelpString("REDACTED TOWER", screenW/2, screenH/2-40, 0, 0);
            break;
        case 1:
            drawHelpString("Build a tower", screenW/2, screenH/2-40, 0, 0);
            break;
        case 2:
            drawHelpString("With big, beautiful,", screenW/2, screenH/2-40, 0, 0);
            break;
        case 3:
        case 4:
        case 5:
            drawHelpString("black boxes.", screenW/2, screenH/2-40, 0, 0);
            break;
        case 6:
        case 7:
        case 8:
            drawHelpString("See how far you can go", screenW/2, screenH/2-40, 0, 0);
            break;
        case 9:
        case 10:
        case 11:
            drawHelpString("before it all tumbles down.", screenW/2, screenH/2-40, 0, 0);
            break;
    }
}

void ofApp::drawHelpString(string s, int x1, int y1, int yOffset, int row) {
    helpFont.drawString(s, x1 - helpFont.stringWidth(s)/2, y1 + yOffset + helpTextHeight * row) ;
}


//--------------------------------------------------------------
void ofApp::exit(){

}

//--------------------------------------------------------------
void ofApp::touchDown(ofTouchEventArgs & touch){
    if (touch.y < (screenH-50)) {
        if (scrollingState == 0) {
            scrollingState = -1;  // wait for move state
            ofLog(OF_LOG_VERBOSE, "Scrolling State %d", scrollingState);
            startTouchId = touch.id;
            startTouchX = (int)touch.x;
            startTouchY = (int)touch.y;
            prevXOffset = xOffset;
            prevYOffset = yOffset;
        }
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
        xOffset = prevXOffset + (touch.x - startTouchX);
        yOffset = prevYOffset + (touch.y - startTouchY);
        if (yOffset < 0) yOffset = 0;
        ofLog(OF_LOG_VERBOSE, "Scrolling %d", yOffset);
        if (xOffset < -2000) xOffset = -2000;
        if (xOffset > 2000) xOffset = 2000;
        ofLog(OF_LOG_VERBOSE, "Scrolling %d", xOffset);
    }
}

//--------------------------------------------------------------
void ofApp::touchUp(ofTouchEventArgs & touch){
    if ((scrollingState == -1) && (startTouchId == touch.id)) {
        scrollingState = 0;
        startTouchId = -1;
        startTouchX = 0;
        startTouchY = 0;
        if (blocksOnScreen < nBlocks) {
            Block * b = blocks[blocksOnScreen].get();
            b->setPhysics(1, 0 , 1);
            b->setup(box2d.getWorld(), ((touch.x-xOffset)/cameraScale)/b->physicsScale, ((touch.y - yOffset)/cameraScale)/b->physicsScale, b->w/b->physicsScale, b->h/b->physicsScale);
            b->init();
            if (blocksOnScreen < (nBlocks-1)) blocksOnScreen++;
        //pd.sendBang("playThud");
        }
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
    //takePicture();
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
    int xMin = 0;
    int yMin = 0;
    int xMax = 0;
    int yMax = 0;
    
    for (int i=0; i < blocksOnScreen; i++) {
        int x = blocks[i].get()->x*cameraScale;
        int y = blocks[i].get()->y*cameraScale;
        if (x < xMin) xMin = x;
        if (x > xMax) xMax = x;
        if (y < yMin) yMin = y;
        if (y > yMax) yMax = y;
    }
    xMin -= 50;
    xMax += 50;
    
     ofFbo fbo;
     ofImage img;
     ofPixels pixels;
    
    int imgW = abs(xMax)+abs(xMin);
    int imgH  =abs(yMax)+abs(yMin);
    fbo.allocate(imgW, imgH+20, GL_RGBA);
     
    fbo.begin();
    ofSetHexColor(0xFFFFFF);
    ofSetRectMode(OF_RECTMODE_CORNER);
    background[currentBackground].draw(0, 0, imgW, imgH+20);
    
    ofPushMatrix();
    ofTranslate(abs(xMin), abs(yMin));
    
    groundImg.draw(xMin, imgH, imgW, 20);
    ofScale( cameraScale, cameraScale, 1.f );
    
    ofSetHexColor(0xABDB44);
    for (int i=0; i < blocksOnScreen; i++) {
        blocks[i].get()->drawMe();
    }
    ofPopMatrix();
    ofSetColor(60);
    ofSetHexColor(0x333333);
    helpFont.drawString(to_string(blocksOnScreen) + "/790" , 20, imgH);
     fbo.end();
     
    fbo.readToPixels(pixels);
    img.setFromPixels(pixels);
    img.update();
    img.save(ofxiOSGetDocumentsDirectory() + "foo.png", OF_IMAGE_QUALITY_BEST);
}

float ofApp::setAVSessionSampleRate(float preferredSampleRate) {
    
    NSError *audioSessionError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    // disable active
    [session setActive:NO error:&audioSessionError];
    if (audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    
    // set category
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionMixWithOthers|AVAudioSessionCategoryOptionDefaultToSpeaker error:&audioSessionError];
    if(audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    
    // try to set the preferred sample rate
    [session setPreferredSampleRate:preferredSampleRate error:&audioSessionError];
    if(audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    
    // *** Activate the audio session before asking for the "current" values ***
    [session setActive:YES error:&audioSessionError];
    if (audioSessionError) {
        NSLog(@"Error %ld, %@", (long)audioSessionError.code, audioSessionError.localizedDescription);
    }
    ofLogNotice() << "AVSession samplerate: " << session.sampleRate << ", I/O buffer duration: " << session.IOBufferDuration;
    
    // our actual samplerate, might be differnt aka 48k on iPhone 6S
    return session.sampleRate;
}

//--------------------------------------------------------------
void ofApp::audioReceived(float * input, int bufferSize, int nChannels) {
    pd.audioIn(input, bufferSize, nChannels);
}

//--------------------------------------------------------------
void ofApp::audioRequested(float * output, int bufferSize, int nChannels) {
    pd.audioOut(output, bufferSize, nChannels);
}
