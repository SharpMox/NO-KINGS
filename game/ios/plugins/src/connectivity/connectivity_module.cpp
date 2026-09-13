#include "connectivity_module.h"

#include "core/config/engine.h"

#include "connectivity.h"

Connectivity *connectivity;

void register_connectivity_types() {
	connectivity = memnew(Connectivity);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Connectivity", connectivity));
}

void unregister_connectivity_types() {
	if (connectivity) {
		memdelete(connectivity);
	}
}
