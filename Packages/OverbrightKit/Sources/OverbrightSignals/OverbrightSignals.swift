// OverbrightSignals/OverbrightSignals.swift — module overview. ARCHITECTURE.md §2.1, §7.1–§7.3, §10.8.
//
// System signals and conflicting apps (L1: Core + Policy + Apple frameworks; MainActor by default):
//   Monitor/     SignalsMonitor (implements SystemSignals and ServiceLifecycle: the snapshot, synchronous event
//                delivery, the always-on notifications, the boost-only sources), SignalSource (energy classes),
//                SignalsPlatform + LiveSignalsPlatform (every system read and registration), MainHop,
//                MainActorCallback and DistributedObserver (nonisolated entry points; distributed notifications
//                delivered immediately), DeadlineTimer (one pending deadline on the TimeSource), SessionState.
//   Power/       PowerSourceReader (the synchronous IOPS read), PowerSourceNotifications (the two IOKit run-loop
//                sources), ThermalLevel from ProcessInfo.
//   FullScreen/  FullScreenDetector (pure, ported from Cranny and extended: Split View, regular apps, our PID,
//                menu bar by PID, full-screen video), MenuBarPresence (3 s sticky absence), WindowListSnapshot
//                (@concurrent window list), FullScreenTracker (0.6 s debounce, one outcome per check).
//   Playback/    PlaybackAssertions (display-sleep assertions by process).
//   Apps/        RunningAppInfo, GameCategory (LSApplicationCategoryType).
//   Idle/        IdleScheduler (pure deadline), OLEDPresence.
//   Camera/      CameraMonitor, CameraDebouncer (1 s on / 3 s off), CameraTransport (filter), CameraDevices +
//                CoreMediaIOCameras (listeners on the main queue).
//   Schedule/    ScheduleTimer (pure boundaries in local time).
//   Conflicts/   RunningAppsConflictProbe (implements ConflictProbe over Policy's matcher), RunningAppsSource +
//                WorkspaceRunningApps, CodeSigningTeam, ProcessScanner (libproc, off the main actor, on demand).
//   Focus/       FocusDirectiveStore (the persisted Focus filter directive).
//
// Zero work while the boost is inactive except the always-on event notifications (D22). Every entry point the system
// may call off the main thread is nonisolated and has an off-main test (§8.1 rule 2). Names are never compared (D8).
import OverbrightCore
import OverbrightPolicy
