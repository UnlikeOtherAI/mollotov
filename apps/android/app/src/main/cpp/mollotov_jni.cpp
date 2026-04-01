#include <jni.h>

#include <codecvt>
#include <cstdint>
#include <locale>
#include <string>

#include "mollotov/state_c_api.h"

namespace {

using BookmarkStoreRef = MollotovBookmarkStoreRef;
using HistoryStoreRef = MollotovHistoryStoreRef;
using NetworkTrafficStoreRef = MollotovNetworkTrafficStoreRef;

template <typename T>
T HandleFromJLong(jlong handle) {
  return reinterpret_cast<T>(static_cast<intptr_t>(handle));
}

template <typename T>
jlong JLongFromHandle(T handle) {
  return static_cast<jlong>(reinterpret_cast<intptr_t>(handle));
}

std::string JStringToUtf8(JNIEnv* env, jstring value) {
  if (value == nullptr) {
    return {};
  }

  const jchar* chars = env->GetStringChars(value, nullptr);
  if (chars == nullptr) {
    return {};
  }

  const jsize length = env->GetStringLength(value);
  const auto* utf16 = reinterpret_cast<const char16_t*>(chars);
  std::u16string utf16_string(utf16, utf16 + length);
  env->ReleaseStringChars(value, chars);

  try {
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter;
    return converter.to_bytes(utf16_string);
  } catch (...) {
    return {};
  }
}

jstring Utf8ToJString(JNIEnv* env, const std::string& value) {
  try {
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter;
    const std::u16string utf16 = converter.from_bytes(value);
    return env->NewString(reinterpret_cast<const jchar*>(utf16.data()),
                          static_cast<jsize>(utf16.size()));
  } catch (...) {
    return nullptr;
  }
}

jstring TakeOwnedCString(JNIEnv* env, char* value) {
  if (value == nullptr) {
    return nullptr;
  }

  const std::string utf8(value);
  mollotov_free_string(value);
  return Utf8ToJString(env, utf8);
}

}  // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreCreateNative(JNIEnv*, jobject) {
  return JLongFromHandle(mollotov_bookmark_store_create());
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreDestroyNative(JNIEnv*,
                                                                           jobject,
                                                                           jlong handle) {
  mollotov_bookmark_store_destroy(HandleFromJLong<BookmarkStoreRef>(handle));
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreAdd(JNIEnv* env,
                                                                 jobject,
                                                                 jlong handle,
                                                                 jstring title,
                                                                 jstring url) {
  const std::string native_title = JStringToUtf8(env, title);
  const std::string native_url = JStringToUtf8(env, url);
  mollotov_bookmark_store_add(HandleFromJLong<BookmarkStoreRef>(handle),
                              native_title.c_str(),
                              native_url.c_str());
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreRemove(JNIEnv* env,
                                                                    jobject,
                                                                    jlong handle,
                                                                    jstring id) {
  const std::string native_id = JStringToUtf8(env, id);
  mollotov_bookmark_store_remove(HandleFromJLong<BookmarkStoreRef>(handle), native_id.c_str());
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreRemoveAll(JNIEnv*,
                                                                       jobject,
                                                                       jlong handle) {
  mollotov_bookmark_store_remove_all(HandleFromJLong<BookmarkStoreRef>(handle));
}

JNIEXPORT jstring JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreToJson(JNIEnv* env,
                                                                    jobject,
                                                                    jlong handle) {
  return TakeOwnedCString(env,
                          mollotov_bookmark_store_to_json(
                              HandleFromJLong<BookmarkStoreRef>(handle)));
}

JNIEXPORT jint JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreCount(JNIEnv*,
                                                                   jobject,
                                                                   jlong handle) {
  return mollotov_bookmark_store_count(HandleFromJLong<BookmarkStoreRef>(handle));
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_bookmarkStoreLoadJson(JNIEnv* env,
                                                                      jobject,
                                                                      jlong handle,
                                                                      jstring json) {
  const std::string native_json = JStringToUtf8(env, json);
  mollotov_bookmark_store_load_json(HandleFromJLong<BookmarkStoreRef>(handle),
                                    native_json.c_str());
}

JNIEXPORT jlong JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreCreateNative(JNIEnv*, jobject) {
  return JLongFromHandle(mollotov_history_store_create());
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreDestroyNative(JNIEnv*,
                                                                          jobject,
                                                                          jlong handle) {
  mollotov_history_store_destroy(HandleFromJLong<HistoryStoreRef>(handle));
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreRecord(JNIEnv* env,
                                                                   jobject,
                                                                   jlong handle,
                                                                   jstring url,
                                                                   jstring title) {
  const std::string native_url = JStringToUtf8(env, url);
  const std::string native_title = JStringToUtf8(env, title);
  mollotov_history_store_record(HandleFromJLong<HistoryStoreRef>(handle),
                                native_url.c_str(),
                                native_title.c_str());
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreClear(JNIEnv*,
                                                                  jobject,
                                                                  jlong handle) {
  mollotov_history_store_clear(HandleFromJLong<HistoryStoreRef>(handle));
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreUpdateLatestTitle(JNIEnv* env,
                                                                              jobject,
                                                                              jlong handle,
                                                                              jstring url,
                                                                              jstring title) {
  const std::string native_url = JStringToUtf8(env, url);
  const std::string native_title = JStringToUtf8(env, title);
  mollotov_history_store_update_latest_title(HandleFromJLong<HistoryStoreRef>(handle),
                                             native_url.c_str(),
                                             native_title.c_str());
}

JNIEXPORT jstring JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreToJson(JNIEnv* env,
                                                                   jobject,
                                                                   jlong handle) {
  return TakeOwnedCString(env,
                          mollotov_history_store_to_json(
                              HandleFromJLong<HistoryStoreRef>(handle)));
}

JNIEXPORT jint JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreCount(JNIEnv*,
                                                                  jobject,
                                                                  jlong handle) {
  return mollotov_history_store_count(HandleFromJLong<HistoryStoreRef>(handle));
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_historyStoreLoadJson(JNIEnv* env,
                                                                     jobject,
                                                                     jlong handle,
                                                                     jstring json) {
  const std::string native_json = JStringToUtf8(env, json);
  mollotov_history_store_load_json(HandleFromJLong<HistoryStoreRef>(handle),
                                   native_json.c_str());
}

JNIEXPORT jlong JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreCreateNative(JNIEnv*, jobject) {
  return JLongFromHandle(mollotov_network_traffic_store_create());
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreDestroyNative(JNIEnv*,
                                                                                 jobject,
                                                                                 jlong handle) {
  mollotov_network_traffic_store_destroy(HandleFromJLong<NetworkTrafficStoreRef>(handle));
}

JNIEXPORT jboolean JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreAppendJson(JNIEnv* env,
                                                                              jobject,
                                                                              jlong handle,
                                                                              jstring entryJson) {
  const std::string native_json = JStringToUtf8(env, entryJson);
  return mollotov_network_traffic_store_append_json(
             HandleFromJLong<NetworkTrafficStoreRef>(handle), native_json.c_str()) != 0;
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreAppendDocumentNavigation(
    JNIEnv* env,
    jobject,
    jlong handle,
    jstring url,
    jint statusCode,
    jstring contentType,
    jstring responseHeadersJson,
    jlong size,
    jstring startTime,
    jint duration) {
  const std::string native_url = JStringToUtf8(env, url);
  const std::string native_content_type = JStringToUtf8(env, contentType);
  const std::string native_response_headers = JStringToUtf8(env, responseHeadersJson);
  const std::string native_start_time = JStringToUtf8(env, startTime);
  mollotov_network_traffic_store_append_document_navigation(
      HandleFromJLong<NetworkTrafficStoreRef>(handle),
      native_url.c_str(),
      statusCode,
      native_content_type.c_str(),
      native_response_headers.c_str(),
      size,
      native_start_time.c_str(),
      duration);
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreClear(JNIEnv*,
                                                                         jobject,
                                                                         jlong handle) {
  mollotov_network_traffic_store_clear(HandleFromJLong<NetworkTrafficStoreRef>(handle));
}

JNIEXPORT jboolean JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreSelect(JNIEnv*,
                                                                          jobject,
                                                                          jlong handle,
                                                                          jint index) {
  return mollotov_network_traffic_store_select(
             HandleFromJLong<NetworkTrafficStoreRef>(handle), index) != 0;
}

JNIEXPORT jint JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreSelectedIndex(JNIEnv*,
                                                                                 jobject,
                                                                                 jlong handle) {
  return mollotov_network_traffic_store_selected_index(
      HandleFromJLong<NetworkTrafficStoreRef>(handle));
}

JNIEXPORT jstring JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreGetSelectedJson(JNIEnv* env,
                                                                                   jobject,
                                                                                   jlong handle) {
  return TakeOwnedCString(env,
                          mollotov_network_traffic_store_get_selected_json(
                              HandleFromJLong<NetworkTrafficStoreRef>(handle)));
}

JNIEXPORT jstring JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreToJson(JNIEnv* env,
                                                                          jobject,
                                                                          jlong handle) {
  return TakeOwnedCString(env,
                          mollotov_network_traffic_store_to_json(
                              HandleFromJLong<NetworkTrafficStoreRef>(handle)));
}

JNIEXPORT jstring JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreToSummaryJson(
    JNIEnv* env,
    jobject,
    jlong handle,
    jstring method,
    jstring category,
    jstring statusRange,
    jstring urlPattern) {
  const std::string native_method = JStringToUtf8(env, method);
  const std::string native_category = JStringToUtf8(env, category);
  const std::string native_status_range = JStringToUtf8(env, statusRange);
  const std::string native_url_pattern = JStringToUtf8(env, urlPattern);
  return TakeOwnedCString(
      env,
      mollotov_network_traffic_store_to_summary_json(
          HandleFromJLong<NetworkTrafficStoreRef>(handle),
          native_method.c_str(),
          native_category.c_str(),
          native_status_range.c_str(),
          native_url_pattern.c_str()));
}

JNIEXPORT jint JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreCount(JNIEnv*,
                                                                         jobject,
                                                                         jlong handle) {
  return mollotov_network_traffic_store_count(HandleFromJLong<NetworkTrafficStoreRef>(handle));
}

JNIEXPORT void JNICALL
Java_com_mollotov_browser_nativecore_NativeCore_networkTrafficStoreLoadJson(JNIEnv* env,
                                                                            jobject,
                                                                            jlong handle,
                                                                            jstring json) {
  const std::string native_json = JStringToUtf8(env, json);
  mollotov_network_traffic_store_load_json(HandleFromJLong<NetworkTrafficStoreRef>(handle),
                                           native_json.c_str());
}

}  // extern "C"
