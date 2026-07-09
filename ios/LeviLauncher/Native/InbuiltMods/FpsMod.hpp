#ifndef FPSMOD_HPP
#define FPSMOD_HPP

namespace FpsMod {

    void setEnabled(bool enabled);
    bool isEnabled();
    void onFrame();
    int getFps();

} // namespace FpsMod

#endif // FPSMOD_HPP
