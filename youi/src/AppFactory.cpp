// © You i Labs Inc. 2000-2017. All rights reserved.
#include "AppFactory.h"
#include "App.h"

#define APP_NAME "Video Player"

#define APP_DENSITY (72)
#if defined(YI_PS4) || defined(YI_XBOX_360) || defined(YI_PS3)
#define APP_WIDTH (1920)
#define APP_HEIGHT (1080)
#else
#define APP_WIDTH (1280)
#define APP_HEIGHT (720)
#endif

std::unique_ptr<CYIApp> AppFactory::Create()
{
    return std::make_unique<App>();
}

int AppFactory::GetWindowWidth()
{
    return APP_WIDTH;
}

int AppFactory::GetWindowHeight()
{
    return APP_HEIGHT;
}

int AppFactory::GetScreenDensity()
{
    return APP_DENSITY;
}

const char * AppFactory::GetWindowName()
{
    return APP_NAME;
}
