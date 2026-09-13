// NO-64: asks iOS whether there is a network path, via NWPathMonitor.
// Built like the vendored gamecenter/icloud plugins — see ../../README.md.

#ifndef CONNECTIVITY_H
#define CONNECTIVITY_H

#include "core/object/class_db.h"

class Connectivity : public Object {
	GDCLASS(Connectivity, Object);

	static void _bind_methods();

public:
	bool is_online();

	Connectivity();
	~Connectivity();
};

#endif
