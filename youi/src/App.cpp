// © You i Labs Inc. 2000-2017. All rights reserved.
#include "App.h"
#include <cxxreact/JSBigString.h>
#include <glog/logging.h>

#if defined(YI_LOCAL_JS_APP)
    #if defined(YI_INLINE_JS_APP)
        #include "youireact/JsBundleLoaderInlineString.h"
        const char INLINE_JS_BUNDLE_STRING[] =
            #include "InlineJSBundleGenerated/index.youi.bundle"
            ;
    #else
        #include "youireact/JsBundleLoaderLocalAsset.h"
    #endif
#else
    #include "youireact/JsBundleLoaderRemote.h"
#endif

App::App() = default;

App::~App() = default;

using namespace yi::react;

bool App::UserInit()
{
#if !defined(YI_MINI_GLOG)
    // miniglog defines this using a non-const char * causing a compile error and it has no implementation anyway.
    static bool isGoogleLoggingInitialized = false;
    if (!isGoogleLoggingInitialized)
    {
        google::InitGoogleLogging("--logtostderr=1");
        isGoogleLoggingInitialized = true;
    }
#endif

    
#if defined(YI_LOCAL_JS_APP)
    #if defined(YI_INLINE_JS_APP)
        std::unique_ptr<JsBundleLoader> pBundleLoader(new JsBundleLoaderInlineString(INLINE_JS_BUNDLE_STRING));
    #else
        std::unique_ptr<JsBundleLoader> pBundleLoader(new JsBundleLoaderLocalAsset());
    #endif
#else
    std::unique_ptr<JsBundleLoader> pBundleLoader(new JsBundleLoaderRemote());
#endif
    
    PlatformApp::SetJsBundleLoader(std::move(pBundleLoader));
    return PlatformApp::UserInit();
}

bool App::UserStart()
{
    return PlatformApp::UserStart();
}

void App::UserUpdate()
{
    PlatformApp::UserUpdate();
}
