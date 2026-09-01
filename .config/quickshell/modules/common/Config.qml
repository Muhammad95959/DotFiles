pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

QtObject {
  // ── Bar ────────────────────────────────────────────────────────────
  readonly property int barHeight: 24
  readonly property int barExclusiveZone: 24

  // ── Spacing ────────────────────────────────────────────────────────
  readonly property int pLauncherLeft: 8
  readonly property int mLauncherRight: 8
  readonly property int mWorkspacesOuterPad: 8
  readonly property int pWorkspacesBtnPad: 2
  readonly property int mWorkspacesGap: 8
  readonly property int mSubmapPad: 6
  readonly property int pSubmapInnerPad: 8
  readonly property int mWindowPad: 8
  readonly property int mClockPad: 5
  readonly property int mSepPad: 8
  readonly property int mBilalPad: 5
  readonly property int mBandwidthPad: 5
  readonly property int pBandwidthUnitGap: 1
  readonly property int pBandwidthIconGap: 5
  readonly property int mLanguagePad: 5
  readonly property int pLanguageIconGap: 5
  readonly property int mCpuPad: 5
  readonly property int pCpuIconGap: 5
  readonly property int mVolumePad: 5
  readonly property int pVolumeIconGap: 5
  readonly property int mBatteryPad: 5
  readonly property int pBatteryIconGap: 5
  readonly property int mNetworkPad: 5
  readonly property int pNetworkIconGap: 5
  readonly property int mTrayOuterPad: 5
  readonly property int pTrayIconGap: 5
  readonly property int mPowermenuLeft: 5
  readonly property int pPowermenuRight: 8

  // ── Font Sizes ─────────────────────────────────────────────────────
  readonly property int fontSizeText: 12
  readonly property int fontSizeLauncherIcon: 14
  readonly property int fontSizeWorkspaceIcon: 12
  readonly property int fontSizePowermenuIcon: 14
  readonly property int fontSizeLanguageIcon: 14
  readonly property int fontSizeCpuIcon: 15
  readonly property int fontSizeVolumeIcon: 15
  readonly property int fontSizeBatteryIcon: 12
  readonly property int fontSizeNetworkIcon: 13
  readonly property int trayIconSize: 14

  // ── Thresholds ─────────────────────────────────────────────────────
  readonly property int batteryUrgentPct: 10
  readonly property int batteryWarningPct: 20

  // ── Intervals (ms) ─────────────────────────────────────────────────
  readonly property int bandwidthIntervalMs: 1000
  readonly property int cpuIntervalMs: 2000
  readonly property int networkIntervalMs: 10000
  readonly property int bilalIntervalMs: 30000
  readonly property int bilalNotifyDurationMs: 30000

  // ── Commands ───────────────────────────────────────────────────────
  readonly property var screenshotCmd: ["flameshot", "gui"]
  readonly property var systemMonitorCmd: ["kitty", "-e", "--hold", "btm"]
  readonly property var volumeMixerCmd: ["pavucontrol"]
  readonly property string bilalScriptPath: "~/Scripts/bilal.sh"

  // ── Window Title ───────────────────────────────────────────────────
  readonly property int windowTitleMaxWidth: 260
  readonly property var windowTitleRewrites: ({
    "brave-hnpfjngllnobngcgfapefoaidbinmjnm-Default": "whatsapp-web",
    "brave-translate.google.com.eg__-Default": "brave-translate"
  })

  // ── Workspaces ─────────────────────────────────────────────────────
  readonly property var workspacePersistentIds: [1,2,3,4,5,6,7,8,9]
  readonly property int workspaceUrgentWidth: 40
  readonly property int workspaceUrgentRadius: 4

  // ── Power ──────────────────────────────────────────────────────────
  readonly property var powerShutdownCmd: ["systemctl", "poweroff"]
  readonly property var powerRebootCmd: ["systemctl", "reboot"]
  readonly property var powerLogoutCmd: ["hyprctl", "dispatch", "exit"]
  readonly property var powerSuspendCmd: ["systemctl", "suspend"]
  readonly property var powerLockCmd: ["loginctl", "lock-session"]
  readonly property var powerHibernateCmd: ["systemctl", "hibernate"]
}
