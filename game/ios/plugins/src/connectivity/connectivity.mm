// NO-64: the monitor is the SUBSCRIPTION — iOS pushes every path change into
// the handler below — and is_online() just reads its latest verdict, so the
// GDScript poll in menu.gd costs an atomic load.

#include "connectivity.h"

#import <Network/Network.h>

#include <atomic>

// True until the monitor's first update, which it delivers right after start:
// "cannot tell yet" fails open, the same rule as scripts/connectivity.gd.
static std::atomic<bool> online_now(true);
static nw_path_monitor_t monitor = nil;

void Connectivity::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_online"), &Connectivity::is_online);
}

bool Connectivity::is_online() {
	return online_now.load();
}

Connectivity::Connectivity() {
	monitor = nw_path_monitor_create();
	nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
		online_now.store(nw_path_get_status(path) == nw_path_status_satisfied);
	});
	nw_path_monitor_set_queue(monitor, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
	nw_path_monitor_start(monitor);
}

Connectivity::~Connectivity() {
	if (monitor) {
		nw_path_monitor_cancel(monitor);
		monitor = nil;
	}
}
