#!/usr/bin/env python3
"""Rebuild the checked-in Xcode project using only the Python standard library.

Not required to open/build Afterglow. Run after adding new source files.
"""
import hashlib
import json
import pathlib
import plistlib
from xml.sax.saxutils import escape

ROOT = pathlib.Path(__file__).resolve().parents[1]
OBJECTS = {}

def uid(value):
    return hashlib.sha1(value.encode()).hexdigest()[:24].upper()

def add(key, **values):
    identifier = uid(key)
    OBJECTS[identifier] = values
    return identifier

def render(value, level=0):
    indent = '\t' * level
    if isinstance(value, dict):
        return '{\n' + ''.join(indent + '\t' + json.dumps(str(k)) + ' = ' + render(v, level + 1) + ';\n' for k, v in value.items()) + indent + '}'
    if isinstance(value, list):
        return '(\n' + ''.join(indent + '\t' + render(v, level + 1) + ',\n' for v in value) + indent + ')'
    return json.dumps(str(value))

def write_plist(path, data):
    (ROOT / path).write_bytes(plistlib.dumps(data, sort_keys=False))

common_info = {
    'CFBundleDevelopmentRegion': 'en',
    'CFBundleDisplayName': 'Afterglow',
    'CFBundleExecutable': '$(EXECUTABLE_NAME)',
    'CFBundleIdentifier': '$(PRODUCT_BUNDLE_IDENTIFIER)',
    'CFBundleInfoDictionaryVersion': '6.0',
    'CFBundleName': '$(PRODUCT_NAME)',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': '$(MARKETING_VERSION)',
    'CFBundleVersion': '$(CURRENT_PROJECT_VERSION)',
    'NSAppleMusicUsageDescription': 'Search your Apple Music library and play music you choose in Afterglow.',
    'NSMicrophoneUsageDescription': 'Animate visuals with sound from your microphone. Audio is processed on-device and is never recorded or uploaded.',
    'AfterglowMusicKitEnabled': '$(AFTERGLOW_MUSICKIT_ENABLED)',
}
write_plist('Config/Info-iOS.plist', dict(common_info, **{
    'LSRequiresIPhoneOS': True,
    'UILaunchScreen': {},
    'UIApplicationSupportsIndirectInputEvents': True,
    'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
    'UISupportedInterfaceOrientations~ipad': ['UIInterfaceOrientationPortrait', 'UIInterfaceOrientationPortraitUpsideDown', 'UIInterfaceOrientationLandscapeLeft', 'UIInterfaceOrientationLandscapeRight'],
}))
write_plist('Config/Info-Mac.plist', dict(common_info, **{
    'LSMinimumSystemVersion': '$(MACOSX_DEPLOYMENT_TARGET)',
    'LSApplicationCategoryType': 'public.app-category.music',
    'NSPrincipalClass': 'NSApplication',
    'NSAudioCaptureUsageDescription': 'Use permitted system audio to animate visuals. Audio and screen frames are never saved or uploaded.',
    'NSScreenCaptureUsageDescription': 'Use ScreenCaptureKit for system audio visualization. Screen frames are discarded.',
}))
write_plist('Config/iOS.entitlements', {})
write_plist('Config/Mac.entitlements', {
    'com.apple.security.app-sandbox': True,
    'com.apple.security.network.client': True,
    'com.apple.security.device.audio-input': True,
    'com.apple.security.files.user-selected.read-only': True,
})
write_plist('Config/PrivacyInfo.xcprivacy', {
    'NSPrivacyTracking': False,
    'NSPrivacyCollectedDataTypes': [],
    'NSPrivacyAccessedAPITypes': [{
        'NSPrivacyAccessedAPIType': 'NSPrivacyAccessedAPICategoryUserDefaults',
        'NSPrivacyAccessedAPITypeReasons': ['CA92.1'],
    }],
})

file_refs = {}
groups = []
file_types = {'.swift':'sourcecode.swift', '.c':'sourcecode.c.c', '.h':'sourcecode.c.h',
              '.plist':'text.plist.xml', '.entitlements':'text.plist.entitlements', '.xcconfig':'text.xcconfig',
              '.xcprivacy':'text.xml', '.md':'net.daringfireball.markdown', '.py':'text.script.python', '.sh':'text.script.sh'}
for directory in ['App','Audio','Core','Services','Views','Visualizers','Config','Tests','Scripts','Docs']:
    children = []
    for path in sorted((ROOT / directory).glob('*')):
        if not path.is_file(): continue
        relative = path.relative_to(ROOT).as_posix()
        file_refs[relative] = add('file:' + relative, isa='PBXFileReference', lastKnownFileType=file_types.get(path.suffix, 'text'),
                                  path=path.name, sourceTree='<group>')
        children.append(file_refs[relative])
    groups.append(add('group:'+directory, isa='PBXGroup', children=children, path=directory, sourceTree='<group>'))
assets = add('assets', isa='PBXFileReference', lastKnownFileType='folder.assetcatalog', path='Assets.xcassets', sourceTree='<group>')
groups.append(assets)
for name in ['README.md', 'Preview.html']:
    groups.append(add('file:'+name, isa='PBXFileReference', lastKnownFileType='text.html' if name.endswith('.html') else 'net.daringfireball.markdown', path=name, sourceTree='<group>'))

products = []
targets = []
for platform in ['iOS','Mac']:
    name = 'Afterglow-' + platform
    product = add('product:'+platform, isa='PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0,
                  path='Afterglow.app', sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    sources = []
    for path, ref in file_refs.items():
        if path.split('/')[0] in ['Tests','Scripts']: continue
        if pathlib.Path(path).suffix in ['.swift','.c']:
            sources.append(add('build:'+platform+':'+path, isa='PBXBuildFile', fileRef=ref))
    source_phase = add('sources:'+platform, isa='PBXSourcesBuildPhase', buildActionMask=2147483647, files=sources, runOnlyForDeploymentPostprocessing=0)
    resource_files = [add('build:'+platform+':assets', isa='PBXBuildFile', fileRef=assets),
                      add('build:'+platform+':privacy', isa='PBXBuildFile', fileRef=file_refs['Config/PrivacyInfo.xcprivacy'])]
    resource_phase = add('resources:'+platform, isa='PBXResourcesBuildPhase', buildActionMask=2147483647, files=resource_files, runOnlyForDeploymentPostprocessing=0)
    framework_phase = add('frameworks:'+platform, isa='PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
    configurations = []
    for mode in ['Debug','Release']:
        settings = {
            'CODE_SIGN_STYLE': 'Automatic', 'DEVELOPMENT_TEAM': '',
            'PRODUCT_BUNDLE_IDENTIFIER': '$(BUNDLE_ID_PREFIX).' + ('ios' if platform == 'iOS' else 'mac'),
            'INFOPLIST_FILE': 'Config/Info-' + platform + '.plist',
            'CODE_SIGN_ENTITLEMENTS': 'Config/' + platform + '.entitlements',
            'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode == 'Debug' else '-O',
            'DEBUG_INFORMATION_FORMAT': 'dwarf' if mode == 'Debug' else 'dwarf-with-dsym',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG' if mode == 'Debug' else '',
            'ENABLE_TESTABILITY': 'YES' if mode == 'Debug' else 'NO',
        }
        if platform == 'iOS':
            settings.update(SDKROOT='iphoneos', IPHONEOS_DEPLOYMENT_TARGET='17.0', TARGETED_DEVICE_FAMILY='1,2',
                            SUPPORTED_PLATFORMS='iphoneos iphonesimulator', SUPPORTS_MACCATALYST='NO',
                            SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD='YES')
        else:
            settings.update(SDKROOT='macosx', MACOSX_DEPLOYMENT_TARGET='14.0', SUPPORTED_PLATFORMS='macosx',
                            CODE_SIGN_IDENTITY='-', LD_RUNPATH_SEARCH_PATHS=['$(inherited)','@executable_path/../Frameworks'])
        configurations.append(add('config:'+name+':'+mode, isa='XCBuildConfiguration', baseConfigurationReference=file_refs['Config/App.xcconfig'],
                                  buildSettings=settings, name=mode))
    config_list = add('configs:'+name, isa='XCConfigurationList', buildConfigurations=configurations, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
    target = add('target:'+platform, isa='PBXNativeTarget', buildConfigurationList=config_list,
                 buildPhases=[source_phase, framework_phase, resource_phase], buildRules=[], dependencies=[], name=name,
                 productName='Afterglow', productReference=product, productType='com.apple.product-type.application')
    targets.append(target)

product_group = add('products', isa='PBXGroup', children=products, name='Products', sourceTree='<group>')
main_group = add('main', isa='PBXGroup', children=groups+[product_group], sourceTree='<group>')
project_configs = []
for mode in ['Debug','Release']:
    project_configs.append(add('project-config:'+mode, isa='XCBuildConfiguration', name=mode,
                              buildSettings={'CLANG_ENABLE_OBJC_ARC':'YES','GCC_C_LANGUAGE_STANDARD':'gnu11',
                                             'GCC_WARN_64_TO_32_BIT_CONVERSION':'YES','CLANG_WARN_DOCUMENTATION_COMMENTS':'YES'}))
project_config_list = add('project-configs', isa='XCConfigurationList', buildConfigurations=project_configs,
                          defaultConfigurationIsVisible=0, defaultConfigurationName='Release')
project = add('project', isa='PBXProject', attributes={'LastUpgradeCheck':'1600','BuildIndependentTargetsInParallel':'YES',
              'TargetAttributes':{target:{'CreatedOnToolsVersion':'16.0'} for target in targets}},
              buildConfigurationList=project_config_list, compatibilityVersion='Xcode 14.0', developmentRegion='en',
              hasScannedForEncodings=0, knownRegions=['en','Base'], mainGroup=main_group, productRefGroup=product_group,
              projectDirPath='', projectRoot='', targets=targets)
project_dir = ROOT / 'Afterglow.xcodeproj'
project_dir.mkdir(exist_ok=True)
content = {'archiveVersion':1,'classes':{},'objectVersion':56,'objects':OBJECTS,'rootObject':project}
(project_dir / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + render(content) + '\n')
workspace = project_dir / 'project.xcworkspace'
workspace.mkdir(exist_ok=True)
(workspace / 'contents.xcworkspacedata').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0"><FileRef location="self:"></FileRef></Workspace>\n')
schemes = project_dir / 'xcshareddata/xcschemes'
schemes.mkdir(parents=True, exist_ok=True)
for platform in ['iOS','Mac']:
    name = 'Afterglow-' + platform
    buildable = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("target:"+platform)}" BuildableName="Afterglow.app" BlueprintName="{name}" ReferencedContainer="container:Afterglow.xcodeproj"/>'
    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
  <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable}</BuildActionEntry></BuildActionEntries>
 </BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
    (schemes / (name + '.xcscheme')).write_text(xml + '\n')
print(f'Generated {project_dir.name}: {len(targets)} app targets, {len(OBJECTS)} objects.')
