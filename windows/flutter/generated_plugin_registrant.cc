//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audioplayers_windows/audioplayers_windows_plugin.h>
#include <audiotags/audiotags_plugin_c_api.h>
#include <flutter_media_metadata/flutter_media_metadata_plugin.h>
#include <permission_handler_windows/permission_handler_windows_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AudioplayersWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioplayersWindowsPlugin"));
  AudiotagsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudiotagsPluginCApi"));
  FlutterMediaMetadataPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterMediaMetadataPlugin"));
  PermissionHandlerWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PermissionHandlerWindowsPlugin"));
}
