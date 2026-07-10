#ifndef NATIVEMODUI_H
#define NATIVEMODUI_H

namespace NativeModUI {

// Registers the native UIKit overlay with UIHook. The implementation lives in
// Objective-C++ so UI state can call the C++ mod engine directly.
void initialize();

} // namespace NativeModUI

#endif
