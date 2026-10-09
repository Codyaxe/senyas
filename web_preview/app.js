// Senyas Interactive Flutter Frontend Preview Controller
document.addEventListener('DOMContentLoaded', () => {
  const screens = {
    intro: {
      id: 'screen-intro',
      nodeId: '57:1254',
      flutterClass: 'IntroductionScreen',
      title: 'Introduction Screen',
      desc: 'Onboarding screen showing the Senyas logo, tagline "Sign. Speak. Understand.", 3 feature pills, and "Get Started" CTA button.',
      code: `class IntroductionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.introBackground,
      body: SafeArea(
        child: Column(
          children: [
            const SenyasStatusBar(isDark: false, textColor: AppColors.primary),
            Expanded(
              child: Column(
                children: [
                  Image.asset(AppAssets.senyasLogo, width: 200),
                  Text('Sign. Speak. Understand.', style: AppTextStyles.h2(color: AppColors.accent2)),
                  Text('An offline two-way communication assistant...', style: AppTextStyles.h3()),
                  // 3 Feature Pills: FSL, Speech-Text, Offline
                  _buildFeaturePill('FSL - Filipino Translation', AppColors.accent2Soft),
                  _buildFeaturePill('Speech - Text Translation', AppColors.accentGreenSoft),
                  _buildFeaturePill('Works Offline (No Internet Needed)', AppColors.accent2Soft),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                    child: Text('Get Started'),
                  ),
                ],
              ),
            ),
            const SenyasHomeIndicator(),
          ],
        ),
      ),
    );
  }
}`,
      actions: [
        'Tap "Get Started" to navigate directly to the Main Home screen.',
        'Uses green-tinted iOS Status Bar (node 32:412).',
        'Responsive layout with Inter Semi-Bold typography.'
      ]
    },

    home: {
      id: 'screen-home',
      nodeId: '2:67',
      flutterClass: 'HomeScreen',
      title: 'Front Page / Home Screen',
      desc: 'Main dashboard featuring top header "Senyas", "Sign to translate to FTL" banner, Sign Translation card, Speech Translation card, and bottom navigation.',
      code: `class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SenyasHeader(title: 'Senyas', subtitle: 'FTL Sign Translator AI'),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              _buildFeaturedCard(), // "Sign to translate to FTL"
              _buildActionCard(
                title: 'Sign Translation',
                subtitle: 'Sign to Text',
                bgColor: AppColors.signCardBg,
                iconAsset: AppAssets.cameraFilled,
                onTap: () => Navigator.pushNamed(context, '/sign-translation'),
              ),
              _buildActionCard(
                title: 'Speech Translation',
                subtitle: 'Voice to Text',
                bgColor: AppColors.speechCardBg,
                iconAsset: AppAssets.micFilled,
                onTap: () => Navigator.pushNamed(context, '/speech-translation'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}`,
      actions: [
        'Tap "Sign Translation" to open live Sign Language Translation camera.',
        'Tap "Speech Translation" to open microphone speech-to-text.',
        'Tap bottom nav items to switch between Home, History, and Profile.'
      ]
    },

    history: {
      id: 'screen-history',
      nodeId: '32:288',
      flutterClass: 'HistoryScreen',
      title: 'History Page',
      desc: 'Chronological list of completed sign translations and speech translations with timestamps and icons.',
      code: `class HistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SenyasHeader(title: 'History'),
        Expanded(
          child: ListView.separated(
            itemCount: defaultHistoryItems.length,
            separatorBuilder: (_, __) => SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = defaultHistoryItems[index];
              return _buildHistoryCard(item);
            },
          ),
        ),
      ],
    );
  }
}`,
      actions: [
        'Displays 5 sample translations from Figma node 32:288.',
        'Tap 3-dots in header to open options (Clear History / Restore sample data).',
        'Distinct icon badges for Sign (teal wave) and Speech (blue spectrum).'
      ]
    },

    profile: {
      id: 'screen-profile',
      nodeId: '37:917',
      flutterClass: 'ProfileScreen',
      title: 'Profile Page',
      desc: 'Profile screen showing app branding and system settings list (About, Model Info, Device, Privacy).',
      code: `class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SenyasHeader(title: 'Profile'),
        Expanded(
          child: Column(
            children: [
              Image.asset(AppAssets.senyasLogo, width: 140),
              Text('Sign. Speak. Understand.', style: AppTextStyles.h3(color: AppColors.accent2)),
              // Settings list:
              _buildProfileRow('About Senyas', 'Version 1.0.0 (Offline)', AppAssets.about),
              _buildProfileRow('Model Info', 'Gemma 4 E28 + Whispher', AppAssets.modelGear,
                onTap: () => Navigator.pushNamed(context, '/settings')),
              _buildProfileRow('Device', 'Cactus (Android)', AppAssets.devicePhone),
              _buildProfileRow('Privacy', 'Your data stays on your device', AppAssets.privacyPadlock),
            ],
          ),
        ),
      ],
    );
  }
}`,
      actions: [
        'Tap "Model Info" to navigate to Settings Page.',
        'Tap "About", "Device", or "Privacy" to view offline system specs.',
        'Branded Senyas logo and slogan hero banner.'
      ]
    },

    settings: {
      id: 'screen-settings',
      nodeId: '36:705',
      flutterClass: 'SettingsScreen',
      title: 'Settings Page',
      desc: 'System configuration with Model Management (Whisper STT Model) and Performance toggles (Disable Thinking Mode, Optimize Performance).',
      code: `class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _whisperSTT = false;
  bool _disableThinking = false;
  bool _optimizePerformance = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SenyasSubHeader(title: 'Settings'),
            Expanded(
              child: ListView(
                children: [
                  _buildSectionHeader('Model Management', 'Automatically loads and unloads models...'),
                  _buildToggleCard('Whisper STT Model', _whisperSTT, (v) => setState(() => _whisperSTT = v)),
                  _buildSectionHeader('Performance', 'Settings to optimize for lower-end devices'),
                  _buildDualToggleCard(
                    'Disable Thinking Mode', _disableThinking, (v) => setState(() => _disableThinking = v),
                    'Optimize Performance', _optimizePerformance, (v) => setState(() => _optimizePerformance = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}`,
      actions: [
        'Toggle switches are fully interactive with smooth sliding animations.',
        'Tap back arrow in subheader to return to the previous screen.',
        'Maintains state across navigation.'
      ]
    },

    speech: {
      id: 'screen-speech',
      nodeId: '32:471',
      flutterClass: 'SpeechTranslationScreen',
      title: 'Speech Translation Screen',
      desc: 'Real-time speech-to-text interface with animated concentric microphone button and bilingual translation bubble cards.',
      code: `class SpeechTranslationScreen extends StatefulWidget {
  @override
  State<SpeechTranslationScreen> createState() => _SpeechTranslationScreenState();
}

class _SpeechTranslationScreenState extends State<SpeechTranslationScreen> {
  bool _isListening = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SenyasSubHeader(title: 'Speech Translation'),
            Expanded(
              child: Column(
                children: [
                  // Concentric Pulsing Microphone Visual
                  _buildConcentricMic(
                    isListening: _isListening,
                    onTap: () => setState(() => _isListening = !_isListening),
                  ),
                  Text(_isListening ? 'Listening...' : 'Tap to Speak'),
                  Text('Speak in Filipino or English'),
                  _buildResultCard('Hello, how are you today?', '→ English'),
                  _buildResultCard('Ano ginagawa mo?', '→ Filipino'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}`,
      actions: [
        'LIVE: tap the mic for real speech recognition (fil-PH). Whispers loads on demand and unloads when you leave.',
        'Every transcript is rewritten into short, easy-to-read sentences — the planned Gemma "deaf-reader" simplify step (rule-based stand-in here).',
        'No SpeechRecognition in this browser? A typed-input fallback runs the same pipeline.',
        'See the "Live Engine" inspector tab for router state and model log.'
      ]
    },

    sign: {
      id: 'screen-sign',
      nodeId: '37:1111',
      flutterClass: 'SignTranslationScreen',
      title: 'Sign Translation Screen',
      desc: 'Live camera viewfinder interface detecting Filipino Sign Language (FSL) with TTS speaker feedback and stop detection control.',
      code: `class SignTranslationScreen extends StatefulWidget {
  @override
  State<SignTranslationScreen> createState() => _SignTranslationScreenState();
}

class _SignTranslationScreenState extends State<SignTranslationScreen> {
  bool _isDetecting = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SenyasSubHeader(title: 'Sign Translation'),
            Expanded(
              child: Column(
                children: [
                  _buildCameraViewfinder(isDetecting: _isDetecting),
                  _buildDetectingStatusIndicator(_isDetecting),
                  _buildRecognizedSignCard('Kamusta ka?', '(How are you?)', onSpeakerTap: _playTTS),
                  _buildStopButton(
                    isDetecting: _isDetecting,
                    onTap: () => setState(() => _isDetecting = !_isDetecting),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}`,
      actions: [
        'LIVE: real webcam + MediaPipe HandLandmarker — open this screen to grant camera access.',
        'Hold a gesture ~0.5s to commit a gloss; pause (hands down) ~1.5s to translate the phrase.',
        'Vocabulary: wave=KAMUSTA, open palm=HELLO, thumbs up=MAGANDA, thumbs down=HINDI, point=IKAW, peace=SALAMAT, fist=TULONG.',
        'Speaker button reads the live translation aloud (TTS). Stop button pauses detection.'
      ]
    },

    statusbar: {
      id: 'screen-statusbar',
      nodeId: '32:412',
      flutterClass: 'SenyasStatusBar',
      title: 'Status Bar Component',
      desc: 'Isolated view of the reusable iOS status bar component specified in Figma node 32:412 with green and dark themes.',
      code: `class SenyasStatusBar extends StatelessWidget {
  final String time;
  final bool isDark;
  final Color? textColor;

  const SenyasStatusBar({
    super.key,
    this.time = '9:41',
    this.isDark = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? (isDark ? AppColors.textDark : AppColors.primary);
    return Container(
      height: 54,
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(time, style: AppTextStyles.statusTime(color: color)),
          Row(
            children: [
              SvgPicture.asset(isDark ? AppAssets.iosSignalDark : AppAssets.iosSignalGreen),
              SizedBox(width: 5),
              SvgPicture.asset(isDark ? AppAssets.iosWifiDark : AppAssets.iosWifiGreen),
              SizedBox(width: 5),
              SvgPicture.asset(isDark ? AppAssets.iosBatteryDark : AppAssets.iosBatteryGreen),
            ],
          ),
        ],
      ),
    );
  }
}`,
      actions: [
        'Used across all 8 screens for authentic device preview.',
        'Configurable tint color: Primary Green (#084131) and Dark Neutral (#30343B).',
        'Precise 54px iOS notch height and 28px horizontal padding.'
      ]
    }
  };

  // State
  let currentScreenKey = 'intro';
  let isListening = false;
  let isSignDetecting = true;

  function switchScreen(key) {
    if (!screens[key]) return;
    currentScreenKey = key;

    // Update screen view
    document.querySelectorAll('.screen-view').forEach(view => {
      view.classList.remove('active');
    });
    const targetView = document.getElementById(screens[key].id);
    if (targetView) targetView.classList.add('active');

    // Update top tabs
    document.querySelectorAll('.screen-tab').forEach(tab => {
      tab.classList.toggle('active', tab.dataset.screen === key);
    });

    // Update bottom navigation active tab sync
    document.querySelectorAll('.nav-item').forEach(item => {
      item.classList.toggle('active', item.dataset.nav === key);
    });

    // Update inspector panel
    const meta = screens[key];
    document.getElementById('inspect-node-id').textContent = meta.nodeId;
    document.getElementById('inspect-flutter-class').textContent = meta.flutterClass;
    document.getElementById('inspect-title').textContent = meta.title;
    document.getElementById('inspect-desc').textContent = meta.desc;
    document.getElementById('code-snippet').textContent = meta.code;

    // Update interaction list
    const interactionList = document.getElementById('interaction-list');
    interactionList.innerHTML = meta.actions.map(act => `<li>${act}</li>`).join('');

    // Live pipeline lifecycle hook
    if (window.__senyasOnScreen) window.__senyasOnScreen(key);
  }

  // Bind Screen Selector Tabs
  document.querySelectorAll('.screen-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      switchScreen(tab.dataset.screen);
    });
  });

  // Bind Bottom Nav Bar across screens
  document.querySelectorAll('.nav-item').forEach(item => {
    item.addEventListener('click', () => {
      const navTarget = item.dataset.nav;
      switchScreen(navTarget);
    });
  });

  // Flow: Get Started -> Home
  const btnGetStarted = document.getElementById('btn-get-started');
  if (btnGetStarted) {
    btnGetStarted.addEventListener('click', () => switchScreen('home'));
  }

  // Flow: Home Banner & Action Cards
  const bannerSign = document.getElementById('banner-sign-quick');
  if (bannerSign) bannerSign.addEventListener('click', () => switchScreen('sign'));

  const actionSign = document.getElementById('action-sign');
  if (actionSign) actionSign.addEventListener('click', () => switchScreen('sign'));

  const actionSpeech = document.getElementById('action-speech');
  if (actionSpeech) actionSpeech.addEventListener('click', () => switchScreen('speech'));

  // Flow: Profile Model Info -> Settings
  const profileModelRow = document.getElementById('profile-model-row');
  if (profileModelRow) profileModelRow.addEventListener('click', () => switchScreen('settings'));

  const homeEllipsisBtn = document.getElementById('home-ellipsis-btn');
  if (homeEllipsisBtn) homeEllipsisBtn.addEventListener('click', () => switchScreen('settings'));

  const profileEllipsisBtn = document.getElementById('profile-ellipsis-btn');
  if (profileEllipsisBtn) profileEllipsisBtn.addEventListener('click', () => switchScreen('settings'));

  // Flow: Back buttons
  const settingsBackBtn = document.getElementById('settings-back-btn');
  if (settingsBackBtn) settingsBackBtn.addEventListener('click', () => switchScreen('profile'));

  const speechBackBtn = document.getElementById('speech-back-btn');
  if (speechBackBtn) speechBackBtn.addEventListener('click', () => switchScreen('home'));

  const signBackBtn = document.getElementById('sign-back-btn');
  if (signBackBtn) signBackBtn.addEventListener('click', () => switchScreen('home'));

  // ================= LIVE MVP ENGINE WIRING =================
  const Engine = window.SenyasEngine;
  const Sign = window.SenyasSign;
  const Speech = window.SenyasSpeech;

  const el = id => document.getElementById(id);
  const engineStateEl = el('engine-state'), engineModelsEl = el('engine-models'),
        engineMemEl = el('engine-mem'), engineLogEl = el('engine-log');

  function renderEngineState() {
    if (!engineStateEl) return;
    engineStateEl.innerHTML = `Router: <strong>${Engine.state.router}</strong>`;
    const m = Engine.state.models;
    engineModelsEl.innerHTML =
      `<span class="eng-model ${m.gemma ? 'on' : ''}">Gemma-4-E2B ${m.gemma ? '●resident' : '○'}</span>` +
      `<span class="eng-model ${m.whisper ? 'on' : ''}">Whisper-small ${m.whisper ? '●loaded' : '○unloaded'}</span>` +
      `<span class="eng-model ${m.landmarker ? 'on' : ''}">HandLandmarker ${m.landmarker ? '●' : '○'}</span>`;
    engineMemEl.textContent = `Simulated RSS: ${Engine.state.memoryMb} MB`;
  }
  function appendEngineLog(entry) {
    if (!engineLogEl) return;
    const div = document.createElement('div');
    div.className = 'eng-log-line eng-' + entry.kind;
    div.textContent = `${entry.t.toLocaleTimeString()}.${String(entry.t.getMilliseconds()).padStart(3,'0')}  ${entry.msg}`;
    engineLogEl.appendChild(div);
    engineLogEl.scrollTop = engineLogEl.scrollHeight;
    while (engineLogEl.children.length > 120) engineLogEl.firstChild.remove();
  }
  Engine.on('log', appendEngineLog);
  Engine.on('router', renderEngineState);
  Engine.on('models', renderEngineState);

  function addHistoryItem(type, text) {
    const list = document.querySelector('.history-list');
    if (!list) return;
    const card = document.createElement('div');
    card.className = 'history-card';
    card.innerHTML = `
      <div class="history-icon-circle ${type === 'sign' ? 'mint-deep' : 'blue-deep'}">
        <img src="../assets/icons/${type === 'sign' ? 'wave_white' : 'spectrum_white'}.svg" alt="${type}">
      </div>
      <div class="history-info">
        <span class="history-tag ${type === 'sign' ? 'mint-tag' : 'blue-tag'}">${type === 'sign' ? 'Sign' : 'Speech'} Translation</span>
        <p class="history-text"></p>
      </div>
      <span class="history-time">${new Date().toLocaleTimeString([], {hour:'numeric', minute:'2-digit'})}</span>`;
    card.querySelector('.history-text').textContent = text;
    list.prepend(card);
  }

  // ---- Sign pipeline UI ----
  let currentTranslation = '';
  const glossTray = el('gloss-tray'), recMain = el('recognized-main'), recSub = el('recognized-sub');

  // Populate vocab cheat sheet
  const vocabList = el('vocab-list');
  if (vocabList) {
    vocabList.innerHTML = Object.entries(Engine.GLOSS_LEXICON)
      .map(([g, v]) => `<li><strong>${v.signHint}</strong> &nbsp;${g} → "${v.fil}" <em>(${v.en})</em></li>`)
      .join('');
  }

  function renderGlossChips(glosses) {
    if (!glossTray) return;
    glossTray.innerHTML = glosses.length
      ? glosses.map(g => `<span class="gloss-chip">${g}</span>`).join('') + '<span class="gloss-hint">pause to translate</span>'
      : '';
  }

  Sign.cb.onStatus = (status, label) => {
    if (handStatusTag) {
      handStatusTag.textContent =
        status === 'hand' ? (label ? `Sign: ${label}` : 'Hand Tracking Active')
        : status === 'no-hand' ? 'No hand detected'
        : status === 'camera-denied' ? 'Camera permission denied'
        : 'Model failed to load';
    }
  };
  Sign.cb.onGloss = (gloss, phrase) => {
    renderGlossChips(phrase);
    if (detectingText) detectingText.textContent =
      phrase.length ? `Recognized: ${phrase.join(' · ')}` : 'Detecting Sign...';
  };
  let streamActive = false;
  Sign.cb.onToken = ch => {
    if (!streamActive) { currentTranslation = ''; streamActive = true; }
    currentTranslation += ch;
    if (recMain) recMain.textContent = currentTranslation;
  };
  Sign.cb.onResult = (sentence, seq) => {
    if (recSub) {
      const lex = seq.map(g => `${g}`).join(' + ');
      recSub.textContent = `(${lex})`;
    }
    addHistoryItem('sign', sentence);
    streamActive = false;
  };

  // Screen lifecycle: start/stop real pipelines per screen
  window.__senyasOnScreen = key => {
    if (key === 'sign') {
      Engine.boot().then(() => Sign.start(el('cam-video'), el('cam-canvas')));
    } else {
      Sign.stop();
    }
    if (key !== 'speech' && Speech.active) Speech.stop();
  };

  // Speech Translation: Concentric Mic Toggle (real STT)
  const micTrigger = document.getElementById('mic-trigger');
  const micStatusText = document.getElementById('mic-status-text');
  const speechInterim = el('speech-interim');
  const speechResults = el('speech-results');
  const speechFallback = el('speech-fallback');
  const typedInput = el('speech-typed-input');

  function addSpeechCard(raw, simplified, lang) {
    const card = document.createElement('div');
    card.className = 'speech-bubble-card';
    card.innerHTML = `<div class="bubble-text"><h4></h4><span class="bubble-tag">→ ${lang} · simplified</span><p class="bubble-raw"></p></div>`;
    card.querySelector('h4').textContent = simplified;
    card.querySelector('.bubble-raw').textContent = 'heard: "' + raw + '"';
    speechResults.prepend(card);
    addHistoryItem('speech', simplified);
  }

  Speech.cb.onState = s => {
    if (s === 'listening') {
      micTrigger.classList.add('listening');
      micStatusText.textContent = 'Listening...';
      micStatusText.style.color = '#318DEF';
      speechFallback.style.display = 'none';
    } else {
      micTrigger.classList.remove('listening');
      micStatusText.textContent = s === 'mic-denied' ? 'Mic denied — type below' : 'Tap to Speak';
      micStatusText.style.color = s === 'mic-denied' ? '#D64545' : '#000000';
      if (s === 'fallback' || s === 'mic-denied') speechFallback.style.display = 'flex';
    }
  };
  Speech.cb.onInterim = t => { speechInterim.textContent = t; };
  Speech.cb.onResult = (raw, simplified, lang) => {
    speechInterim.textContent = '';
    addSpeechCard(raw, simplified, lang);
  };

  if (micTrigger) {
    micTrigger.addEventListener('click', () => {
      if (Speech.active) { Speech.stop(); }
      else { Speech.start(); }
    });
  }
  if (typedInput) {
    typedInput.addEventListener('keydown', e => {
      if (e.key === 'Enter' && typedInput.value.trim()) {
        Speech.submitTyped(typedInput.value.trim());
        typedInput.value = '';
      }
    });
  }

  // Sign Translation: TTS Speaker Click (speaks the live translation)
  const speakerBtn = document.getElementById('speaker-tts-btn');
  if (speakerBtn) {
    speakerBtn.addEventListener('click', () => {
      speakerBtn.style.transform = 'scale(0.92)';
      setTimeout(() => speakerBtn.style.transform = '', 200);

      if ('speechSynthesis' in window && currentTranslation) {
        const utterance = new SpeechSynthesisUtterance(currentTranslation);
        utterance.lang = 'fil-PH';
        window.speechSynthesis.speak(utterance);
      }
    });
  }

  // Sign Translation: Stop / Resume Toggle
  const btnToggleSign = document.getElementById('btn-toggle-sign-detection');
  const handStatusTag = document.getElementById('hand-status-tag');
  const detectingText = document.getElementById('detecting-text');
  const pulseIndicator = document.getElementById('pulse-indicator');
  const stopIconImg = document.getElementById('stop-icon-img');

  if (btnToggleSign) {
    btnToggleSign.addEventListener('click', () => {
      isSignDetecting = !isSignDetecting;
      Sign.setDetecting(isSignDetecting);
      if (isSignDetecting) Sign.manualFlush();
      if (isSignDetecting) {
        btnToggleSign.style.background = '#50B09B';
        stopIconImg.src = '../assets/icons/stop.svg';
        if (handStatusTag) handStatusTag.textContent = 'Hand Tracking Active';
        if (detectingText) detectingText.textContent = 'Detecting Sign...';
        if (pulseIndicator) pulseIndicator.style.animation = 'pulse-dot 1.2s infinite';
      } else {
        btnToggleSign.style.background = '#32D8B4';
        stopIconImg.src = '../assets/icons/camera_filled.svg';
        if (handStatusTag) handStatusTag.textContent = 'Detection Paused';
        if (detectingText) detectingText.textContent = 'Detection Stopped';
        if (pulseIndicator) pulseIndicator.style.animation = 'none';
      }
    });
  }

  // Inspector Tabs Switching
  document.querySelectorAll('.inspect-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.inspect-tab').forEach(t => t.classList.remove('active'));
      document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
      tab.classList.add('active');
      const targetPane = document.getElementById(`pane-${tab.dataset.tab}`);
      if (targetPane) targetPane.classList.add('active');
    });
  });

  // Initialize
  switchScreen('intro');
});
