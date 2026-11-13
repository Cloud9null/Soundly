"""Dependency-free deterministic Xcode project generator. Run from repository root."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent.parent
objects={}
def ident(s): return hashlib.sha1(s.encode()).hexdigest()[:24].upper()
def add(key,isa,**kw):
    i=ident(key); objects[i]={'isa':isa,**kw}; return i
def ref(path,kind): return add('file:'+path,'PBXFileReference',lastKnownFileType=kind,path=path,sourceTree='SOURCE_ROOT')
def buildfile(r): return add('build:'+r,'PBXBuildFile',fileRef=r)
products=[]; targets=[]; configs={}
for name,folder,kind in [('Soundly','iOS','application'),('SoundlyTests','iOSTests','bundle.unit-test'),('SoundlyUITests','iOSUITests','bundle.ui-testing')]:
    src=[ref(str(p.relative_to(root)),'sourcecode.swift') for p in sorted((root/folder).rglob('*.swift'))]
    if name=="Soundly":
        src += [ref(str(p.relative_to(root)),"sourcecode.swift") for p in sorted((root/"Sources/SoundlyCore").rglob("*.swift"))]
    res=[]
    if name=='Soundly':
        res=[ref('iOS/Resources/Assets.xcassets','folder.assetcatalog'),ref('iOS/Resources/PrivacyInfo.xcprivacy','text.xml')]
    prod=add('product:'+name,'PBXFileReference',explicitFileType='wrapper.application' if kind=='application' else 'wrapper.cfbundle',path=name+('.app' if kind=='application' else '.xctest'),sourceTree='BUILT_PRODUCTS_DIR')
    products.append(prod)
    phases=[add('sources:'+name,'PBXSourcesBuildPhase',buildActionMask=2147483647,files=[buildfile(r) for r in src],runOnlyForDeploymentPostprocessing=0),add('resources:'+name,'PBXResourcesBuildPhase',buildActionMask=2147483647,files=[buildfile(r) for r in res],runOnlyForDeploymentPostprocessing=0),add('frameworks:'+name,'PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)]
    if name=='Soundly':
        phases.insert(0,add('icon-export','PBXShellScriptBuildPhase',buildActionMask=2147483647,files=[],inputPaths=['$(SRCROOT)/Brand/Prism-master.png'],outputPaths=['$(SRCROOT)/iOS/Resources/Assets.xcassets/AppIcon.appiconset/Icon.png'],runOnlyForDeploymentPostprocessing=0,shellPath='/bin/sh',shellScript='set -eu\n/usr/bin/sips -z 1024 1024 "$SRCROOT/Brand/Prism-master.png" --out "$SRCROOT/iOS/Resources/Assets.xcassets/AppIcon.appiconset/Icon.png" >/dev/null\n',alwaysOutOfDate=1))
    cl=[]
    for config in ['Debug','Release']:
        settings={'PRODUCT_BUNDLE_IDENTIFIER':'app.soundly.player'+('' if name=='Soundly' else '.'+name),'PRODUCT_NAME':'$(TARGET_NAME)','SWIFT_VERSION':'6.0','IPHONEOS_DEPLOYMENT_TARGET':'26.0','TARGETED_DEVICE_FAMILY':'1','SDKROOT':'iphoneos','CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO'}
        settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG' if config == 'Debug' else ''
        if name=='Soundly': settings.update({'GENERATE_INFOPLIST_FILE':'NO','INFOPLIST_FILE':'iOS/Resources/Info.plist','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','MARKETING_VERSION':'0.6.0','CURRENT_PROJECT_VERSION':'6'})
        elif name=='SoundlyTests': settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Soundly.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Soundly','BUNDLE_LOADER':'$(TEST_HOST)'})
        else: settings['TEST_TARGET_NAME']='Soundly'
        cl.append(add('config:'+name+config,'XCBuildConfiguration',name=config,buildSettings=settings))
    configs[name]=add('configs:'+name,'XCConfigurationList',buildConfigurations=cl,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
    deps=[] if name=='Soundly' else [add('dependency:'+name,'PBXTargetDependency',target=ident('target:Soundly'))]
    targets.append(add('target:'+name,'PBXNativeTarget',name=name,productName=name,productType='com.apple.product-type.'+kind,productReference=prod,buildConfigurationList=configs[name],buildPhases=phases,buildRules=[],dependencies=deps))
productGroup=add('products','PBXGroup',name='Products',children=products,sourceTree='<group>')
group=add('main','PBXGroup',children=[k for k,v in objects.items() if v['isa']=='PBXFileReference' and v.get('sourceTree')=='SOURCE_ROOT']+[productGroup],sourceTree='<group>')
projectconfigs=[add('projectconfig:'+c,'XCBuildConfiguration',name=c,buildSettings={'CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','DEBUG_INFORMATION_FORMAT':'dwarf' if c=='Debug' else 'dwarf-with-dsym','SWIFT_STRICT_CONCURRENCY':'complete'}) for c in ['Debug','Release']]
cl=add('projectconfigs','XCConfigurationList',buildConfigurations=projectconfigs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
proj=add('project','PBXProject',attributes={'LastUpgradeCheck':'2630','BuildIndependentTargetsInParallel':'YES'},buildConfigurationList=cl,compatibilityVersion='Xcode 14.0',developmentRegion='en',knownRegions=['en','Base'],mainGroup=group,productRefGroup=productGroup,projectDirPath='',projectRoot='',targets=targets)
def serialize(v):
    if isinstance(v,dict): return '{\n'+''.join(json.dumps(k)+' = '+serialize(x)+';\n' for k,x in v.items())+'}'
    if isinstance(v,list): return '('+','.join(serialize(x) for x in v)+')'
    return json.dumps(str(v))
p=root/'Soundly.xcodeproj'; p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':proj})+'\n')
s=p/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
def br(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:"+name)}" BuildableName="{name}.{"app" if name=="Soundly" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:Soundly.xcodeproj"/>'
(s/'Soundly.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{br('Soundly')}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" shouldUseLaunchSchemeArgsEnv="YES"><Testables>{''.join('<TestableReference skipped="NO">'+br(n)+'</TestableReference>' for n in ['SoundlyTests','SoundlyUITests'])}</Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{br('Soundly')}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{br('Soundly')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
