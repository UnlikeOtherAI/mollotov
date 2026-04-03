import Foundation

/// Thin Swift wrapper around the core-ai C library.
///
/// The iOS build links core-ai without httplib (no OpenSSL on iOS), so only
/// catalog, fitness, and HF token functions are backed by the native library.
/// Ollama and HF cloud inference are handled by URLSession in AIHandler.swift.
final class AIManager {
    private let ref: MollotovAiManagerRef

    init(modelsDir: String) {
        ref = mollotov_ai_create(modelsDir)!
    }

    deinit {
        mollotov_ai_destroy(ref)
    }

    // MARK: - HF Token

    var hfToken: String {
        get { string(mollotov_ai_get_hf_token(ref)) }
        set { mollotov_ai_set_hf_token(ref, newValue) }
    }

    // MARK: - Model Catalog

    func listApprovedModels() -> [[String: Any]] {
        guard let raw = mollotov_ai_list_approved_models(ref) else { return [] }
        defer { mollotov_ai_free_string(raw) }
        let str = String(cString: raw)
        guard let data = str.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr
    }

    func modelFitness(id: String, ramGB: Double, diskGB: Double) -> [String: Any] {
        guard let raw = mollotov_ai_model_fitness(ref, id, ramGB, diskGB) else { return [:] }
        defer { mollotov_ai_free_string(raw) }
        let str = String(cString: raw)
        guard let data = str.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return dict
    }

    // MARK: - Private

    private func string(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
        guard let ptr else { return "" }
        defer { mollotov_ai_free_string(ptr) }
        return String(cString: ptr)
    }
}
