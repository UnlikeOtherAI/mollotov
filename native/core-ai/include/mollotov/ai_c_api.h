#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MollotovAiManager* MollotovAiManagerRef;

// Lifecycle
MollotovAiManagerRef mollotov_ai_create(const char* models_dir);
void mollotov_ai_destroy(MollotovAiManagerRef mgr);

// String ownership — caller must free returned strings
void mollotov_ai_free_string(char* str);

// HF token
void mollotov_ai_set_hf_token(MollotovAiManagerRef mgr, const char* token);
char* mollotov_ai_get_hf_token(MollotovAiManagerRef mgr);

// Model catalog
char* mollotov_ai_list_approved_models(MollotovAiManagerRef mgr);
char* mollotov_ai_model_fitness(MollotovAiManagerRef mgr,
                                const char* model_id,
                                double total_ram_gb,
                                double disk_free_gb);

// Model store
bool mollotov_ai_is_model_downloaded(MollotovAiManagerRef mgr, const char* model_id);
char* mollotov_ai_model_path(MollotovAiManagerRef mgr, const char* model_id);
bool mollotov_ai_remove_model(MollotovAiManagerRef mgr, const char* model_id);

// Model download (blocking — platform wraps in async)
// Returns NULL on success, error JSON string on failure.
// progress_cb receives (bytes_downloaded, total_bytes, user_data).
typedef void (*MollotovAiDownloadProgressCb)(int64_t downloaded, int64_t total, void* user_data);
char* mollotov_ai_download_model(MollotovAiManagerRef mgr,
                                 const char* model_id,
                                 MollotovAiDownloadProgressCb progress_cb,
                                 void* user_data);

// Ollama
void mollotov_ai_set_ollama_endpoint(MollotovAiManagerRef mgr, const char* endpoint);
bool mollotov_ai_ollama_reachable(MollotovAiManagerRef mgr);
char* mollotov_ai_ollama_list_models(MollotovAiManagerRef mgr);
char* mollotov_ai_ollama_infer(MollotovAiManagerRef mgr,
                               const char* model_name,
                               const char* request_json);

// HF cloud inference
char* mollotov_ai_hf_infer(MollotovAiManagerRef mgr,
                            const char* model_id,
                            const char* request_json);

#ifdef __cplusplus
}
#endif
