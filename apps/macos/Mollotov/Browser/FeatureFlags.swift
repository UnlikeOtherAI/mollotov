import Foundation

enum FeatureFlags {
    /// 3D DOM Inspector — experimental, behind feature flag.
    /// Enable via Settings toggle or `MOLLOTOV_3D_INSPECTOR=1` environment variable.
    static var is3DInspectorEnabled: Bool {
        if UserDefaults.standard.bool(forKey: "enable3DInspector") {
            return true
        }
        if ProcessInfo.processInfo.environment["MOLLOTOV_3D_INSPECTOR"] == "1" {
            return true
        }
        return false
    }
}
