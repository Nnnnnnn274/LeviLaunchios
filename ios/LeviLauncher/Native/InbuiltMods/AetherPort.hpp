#ifndef AETHERPORT_HPP
#define AETHERPORT_HPP

#include <cstddef>

namespace AetherPort {

void initialize();
void setEnabled(bool enabled);
bool isEnabled();
std::size_t contentCount();

} // namespace AetherPort

#endif
