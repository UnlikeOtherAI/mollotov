#include "mollotov/ai_c_api.h"
#include "ai_c_api_internal.h"
#include "model_catalog.h"

extern "C" {

MollotovAiManagerRef mollotov_ai_create(const char* models_dir) {
  try {
    return new MollotovAiManager(
        mollotov::ai_internal::SafeCString(models_dir));
  } catch (...) {
    return nullptr;
  }
}

void mollotov_ai_destroy(MollotovAiManagerRef mgr) {
  delete mgr;
}

void mollotov_ai_free_string(char* str) {
  delete[] str;
}

// --- stubs (filled in by later tasks) ---

void mollotov_ai_set_hf_token(MollotovAiManagerRef, const char*) {}
char* mollotov_ai_get_hf_token(MollotovAiManagerRef) { return nullptr; }
char* mollotov_ai_list_approved_models(MollotovAiManagerRef mgr) {
  if (!mgr) return nullptr;
  try {
    nlohmann::json arr = nlohmann::json::array();
    for (const auto& m : mollotov::ModelCatalog::approved_models()) {
      arr.push_back(m.to_json());
    }
    return mollotov::ai_internal::CopyString(arr.dump());
  } catch (...) {
    return nullptr;
  }
}

char* mollotov_ai_model_fitness(MollotovAiManagerRef mgr, const char* model_id,
                                double total_ram_gb, double disk_free_gb) {
  if (!mgr) return nullptr;
  try {
    const auto* model = mollotov::ModelCatalog::find(
        mollotov::ai_internal::SafeCString(model_id));
    if (!model) return nullptr;
    auto fit = mollotov::ModelCatalog::fitness(*model, total_ram_gb, disk_free_gb);
    return mollotov::ai_internal::CopyString(fit.to_json().dump());
  } catch (...) {
    return nullptr;
  }
}
bool mollotov_ai_is_model_downloaded(MollotovAiManagerRef, const char*) { return false; }
char* mollotov_ai_model_path(MollotovAiManagerRef, const char*) { return nullptr; }
bool mollotov_ai_remove_model(MollotovAiManagerRef, const char*) { return false; }
char* mollotov_ai_download_model(MollotovAiManagerRef, const char*, MollotovAiDownloadProgressCb, void*) { return nullptr; }
void mollotov_ai_set_ollama_endpoint(MollotovAiManagerRef, const char*) {}
bool mollotov_ai_ollama_reachable(MollotovAiManagerRef) { return false; }
char* mollotov_ai_ollama_list_models(MollotovAiManagerRef) { return nullptr; }
char* mollotov_ai_ollama_infer(MollotovAiManagerRef, const char*, const char*) { return nullptr; }
char* mollotov_ai_hf_infer(MollotovAiManagerRef, const char*, const char*) { return nullptr; }

}  // extern "C"
