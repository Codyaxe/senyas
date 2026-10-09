import 'engine_base.dart';
import 'engine_web.dart';
import 'sim_engine.dart';

/// Web: use the JS MediaPipe bridge when present, else simulator.
SenyasEngineApi createEngineImpl() =>
    WebEngine.isSupported() ? WebEngine.create() : SimEngine();
