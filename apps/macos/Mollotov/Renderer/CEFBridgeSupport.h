#import <Foundation/Foundation.h>

#import "CEFBridge.h"

#include "include/capi/cef_app_capi.h"
#include "include/capi/cef_browser_capi.h"
#include "include/capi/cef_client_capi.h"
#include "include/capi/cef_cookie_capi.h"
#include "include/internal/cef_time.h"

typedef struct BridgeClient BridgeClient;

cef_main_args_t CEFBridgeMainArgs(void);
cef_string_t CEFBridgeStringCreate(NSString *value);
void CEFBridgeStringClear(cef_string_t *value);
NSString *CEFBridgeStringFromUserFree(cef_string_userfree_t value);
NSString *CEFBridgeJSONStringForValue(id value);
cef_basetime_t CEFBridgeBaseTimeFromDate(NSDate *value);

BridgeClient *CEFBridgeCreateClient(CEFBridge *owner);
cef_client_t *CEFBridgeClientHandle(BridgeClient *client);
void CEFBridgeReleaseClient(BridgeClient *client);

void CEFBridgeVisitAllCookies(void (^completion)(NSArray<NSDictionary *> *cookies));
void CEFBridgeSetCookie(NSString *name,
                        NSString *value,
                        NSString *domain,
                        NSString *path,
                        BOOL httpOnly,
                        BOOL secure,
                        NSDate *expires,
                        void (^completion)(BOOL success));
void CEFBridgeDeleteAllCookies(void (^completion)(NSInteger deleted));

@interface CEFBridge (SupportCallbacks)
- (void)cefBridgeDidCreateBrowser:(cef_browser_t *)browser;
- (void)cefBridgeWillCloseBrowser;
- (void)cefBridgeUpdateLoadingStateWithIsLoading:(BOOL)isLoading
                                       canGoBack:(BOOL)canGoBack
                                    canGoForward:(BOOL)canGoForward;
- (void)cefBridgeUpdateCurrentURL:(NSString *)url;
- (void)cefBridgeUpdateCurrentTitle:(NSString *)title;
- (void)cefBridgeUpdateLoadingProgress:(double)progress;
- (void)cefBridgeHandleConsoleMessage:(NSString *)message
                               source:(NSString *)source
                                 line:(NSInteger)line;
@end
