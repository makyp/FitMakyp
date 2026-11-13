class AppSettings {
  const AppSettings({
    this.userName = '',
    this.defaultRestSeconds = 120,
    this.restAdjustStepSeconds = 15,
    this.hydrationReminderMinutes = 15,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.warmupEnabled = true,
    this.cooldownEnabled = true,
    this.themeMode = 'sistema',
    this.voiceEnabled = true,
    this.sex = 'no_decir',
    this.cycleEnabled = false,
  });

  final String userName;
  final int defaultRestSeconds;

  /// Paso de los botones +/- del descanso.
  final int restAdjustStepSeconds;

  /// Recordatorio de agua durante el entrenamiento cada N minutos (0 = desactivado).
  final int hydrationReminderMinutes;
  final bool soundEnabled;
  final bool vibrationEnabled;

  /// Calentamiento guiado antes de entrenar y estiramientos al terminar.
  final bool warmupEnabled;
  final bool cooldownEnabled;

  /// 'sistema', 'claro' u 'oscuro'.
  final String themeMode;

  /// Avisos por voz durante el entrenamiento.
  final bool voiceEnabled;

  /// 'mujer', 'hombre' o 'no_decir'.
  final String sex;

  /// Seguimiento del ciclo menstrual (opcional, solo en el teléfono).
  final bool cycleEnabled;

  bool get canTrackCycle => sex != 'hombre';
  bool get showCycle => cycleEnabled && canTrackCycle;

  AppSettings copyWith({
    String? userName,
    int? defaultRestSeconds,
    int? restAdjustStepSeconds,
    int? hydrationReminderMinutes,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? warmupEnabled,
    bool? cooldownEnabled,
    String? themeMode,
    bool? voiceEnabled,
    String? sex,
    bool? cycleEnabled,
  }) =>
      AppSettings(
        userName: userName ?? this.userName,
        defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
        restAdjustStepSeconds: restAdjustStepSeconds ?? this.restAdjustStepSeconds,
        hydrationReminderMinutes: hydrationReminderMinutes ?? this.hydrationReminderMinutes,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        warmupEnabled: warmupEnabled ?? this.warmupEnabled,
        cooldownEnabled: cooldownEnabled ?? this.cooldownEnabled,
        themeMode: themeMode ?? this.themeMode,
        voiceEnabled: voiceEnabled ?? this.voiceEnabled,
        sex: sex ?? this.sex,
        cycleEnabled: cycleEnabled ?? this.cycleEnabled,
      );

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'defaultRestSeconds': defaultRestSeconds,
        'restAdjustStepSeconds': restAdjustStepSeconds,
        'hydrationReminderMinutes': hydrationReminderMinutes,
        'soundEnabled': soundEnabled,
        'vibrationEnabled': vibrationEnabled,
        'warmupEnabled': warmupEnabled,
        'cooldownEnabled': cooldownEnabled,
        'themeMode': themeMode,
        'voiceEnabled': voiceEnabled,
        'sex': sex,
        'cycleEnabled': cycleEnabled,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    return AppSettings(
      userName: (j['userName'] as String?) ?? d.userName,
      defaultRestSeconds: (j['defaultRestSeconds'] as int?) ?? d.defaultRestSeconds,
      restAdjustStepSeconds: (j['restAdjustStepSeconds'] as int?) ?? d.restAdjustStepSeconds,
      hydrationReminderMinutes: (j['hydrationReminderMinutes'] as int?) ?? d.hydrationReminderMinutes,
      soundEnabled: (j['soundEnabled'] as bool?) ?? d.soundEnabled,
      vibrationEnabled: (j['vibrationEnabled'] as bool?) ?? d.vibrationEnabled,
      warmupEnabled: (j['warmupEnabled'] as bool?) ?? d.warmupEnabled,
      cooldownEnabled: (j['cooldownEnabled'] as bool?) ?? d.cooldownEnabled,
      themeMode: (j['themeMode'] as String?) ?? d.themeMode,
      voiceEnabled: (j['voiceEnabled'] as bool?) ?? d.voiceEnabled,
      sex: (j['sex'] as String?) ?? d.sex,
      cycleEnabled: (j['cycleEnabled'] as bool?) ?? d.cycleEnabled,
    );
  }
}
