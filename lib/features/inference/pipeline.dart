import 'model_router.dart';
import 'router_factory_io.dart'
    if (dart.library.js_interop) 'router_factory_web.dart';

export 'model_router.dart';

/// App-wide router singleton. UI should only talk to the pipeline through
/// the engine (lib/engine) or read the ValueNotifiers exposed here.
final ModelRouter pipeline = createRouter();
