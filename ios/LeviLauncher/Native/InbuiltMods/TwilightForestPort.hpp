#ifndef TWILIGHTFORESTPORT_HPP
#define TWILIGHTFORESTPORT_HPP

#include <cstddef>

namespace TwilightForestPort {

void initialize();
void setEnabled(bool enabled);
bool isEnabled();
std::size_t contentCount();

} // namespace TwilightForestPort

#endif
