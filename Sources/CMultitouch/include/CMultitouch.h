#ifndef CMULTITOUCH_H
#define CMULTITOUCH_H

// Struct layout for the private MultitouchSupport.framework touch data.
// Same layout used by long-lived open-source bridges (M5MultitouchSupport
// and friends); stable across macOS releases since ~10.9.

typedef struct {
    float x;
    float y;
} MTPoint;

typedef struct {
    MTPoint position;
    MTPoint velocity;
} MTVector;

typedef struct {
    int frame;
    double timestamp;
    int identifier;
    int state;              // 4 = finger touching the pad
    int fingerId;
    int handId;
    MTVector normalized;    // position in [0,1] x [0,1], origin bottom-left
    float total;
    int field9;
    float angle;
    float majorAxis;
    float minorAxis;
    MTVector absoluteVector;
    int field14;
    int field15;
    float density;
} MTTouch;

typedef void *MTDeviceRef;
typedef int (*MTFrameCallback)(MTDeviceRef device, MTTouch *touches, int numTouches, double timestamp, int frame);

#endif
