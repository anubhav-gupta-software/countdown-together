#!/usr/bin/env python3
"""Write CountdownTogether.xcodeproj from the source tree.

XcodeGen can regenerate the project from project.yml on a Mac.
This script is here so the committed project can be rebuilt in environments
that don't have XcodeGen.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT_NAME = "CountdownTogether"
XCODEPROJ = ROOT / f"{PROJECT_NAME}.xcodeproj"


def oid(*parts: str) -> str:
    digest = hashlib.sha1("::".join(parts).encode()).hexdigest()
    return digest[:24].upper()


def quote(value: str) -> str:
    if value in {"YES", "NO"}:
        return value
    if value.isidentifier() and value.isascii():
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def field(key: str, value: str, indent: int) -> str:
    return f"{' ' * indent}{key} = {value};"


class Writer:
    def __init__(self) -> None:
        self.lines: list[str] = []
        self.defined: set[str] = set()

    def begin(self, identifier: str, isa: str) -> None:
        self.defined.add(identifier)
        self.lines.append(f"\t\t{identifier} /* {isa} */ = {{")
        self.lines.append("\t\t\tisa = " + isa + ";")

    def end(self) -> None:
        self.lines.append("\t\t};")

    def raw(self, text: str) -> None:
        self.lines.append(text)


def settings_block(settings: dict, indent: int = 3) -> list[str]:
    lines = []
    pad = "\t" * indent
    for key, value in settings.items():
        if isinstance(value, list):
            lines.append(f"{pad}{key} = (")
            for item in value:
                lines.append(f"{pad}\t{quote(item)},")
            lines.append(f"{pad});")
        else:
            lines.append(f"{pad}{key} = {quote(str(value))};")
    return lines


def collect(folder: Path, suffix: str) -> list[Path]:
    if not folder.exists():
        return []
    return sorted(path.relative_to(ROOT) for path in folder.rglob(f"*{suffix}") if path.is_file())


def main() -> None:
    app_sources = collect(ROOT / "App", ".swift")
    shared_sources = collect(ROOT / "Shared", ".swift")
    widget_sources = collect(ROOT / "Widget", ".swift")
    test_sources = collect(ROOT / "Tests", ".swift")
    entitlements = collect(ROOT / "Entitlements", ".entitlements")
    tools = collect(ROOT / "tools", ".py")

    app_swift = app_sources + shared_sources
    widget_swift = widget_sources + shared_sources

    project_id = oid("project")
    main_group = oid("group", "main")
    products_group = oid("group", "Products")
    app_target = oid("target", "CountdownTogether")
    widget_target = oid("target", "CountdownWidget")
    test_target = oid("target", "CountdownTogetherTests")
    app_product = oid("product", "CountdownTogether.app")
    widget_product = oid("product", "CountdownWidget.appex")
    test_product = oid("product", "CountdownTogetherTests.xctest")
    app_list = oid("configList", "app")
    widget_list = oid("configList", "widget")
    test_list = oid("configList", "test")
    project_list = oid("configList", "project")

    configs = {}
    for name, kind in (
        ("Debug", "project"),
        ("Release", "project"),
        ("Debug", "app"),
        ("Release", "app"),
        ("Debug", "widget"),
        ("Release", "widget"),
        ("Debug", "test"),
        ("Release", "test"),
    ):
        configs[(kind, name)] = oid("config", kind, name)

    def file_ref(path: str) -> str:
        return oid("file", path)

    def build_file(scope: str, path: str) -> str:
        return oid("build", scope, path)

    sources_phase = {
        "app": oid("phase", "sources", "app"),
        "widget": oid("phase", "sources", "widget"),
        "test": oid("phase", "sources", "test"),
    }
    frameworks_phase = {
        "app": oid("phase", "frameworks", "app"),
        "widget": oid("phase", "frameworks", "widget"),
        "test": oid("phase", "frameworks", "test"),
    }
    resources_phase = {
        "app": oid("phase", "resources", "app"),
        "widget": oid("phase", "resources", "widget"),
    }
    embed_phase = oid("phase", "embed")
    widget_proxy = oid("proxy", "widget")
    test_proxy = oid("proxy", "test")
    widget_dep = oid("dependency", "widget")
    test_dep = oid("dependency", "test")

    extra_files = [
        Path("App/Info.plist"),
        Path("App/Assets.xcassets"),
        Path("Widget/Info.plist"),
        Path("project.yml"),
        *entitlements,
        *tools,
    ]

    writer = Writer()
    writer.lines.append("// !$*UTF8*$!")
    writer.lines.append("{")
    writer.lines.append("\tarchiveVersion = 1;")
    writer.lines.append("\tclasses = {")
    writer.lines.append("\t};")
    writer.lines.append("\tobjectVersion = 56;")
    writer.lines.append("\tobjects = {")
    writer.lines.append("")
    writer.lines.append("/* Begin PBXBuildFile section */")

    def emit_build_file(identifier: str, ref: str, comment: str, attributes: list[str] | None = None) -> None:
        writer.begin(identifier, "PBXBuildFile")
        writer.raw(f"\t\t\tfileRef = {ref} /* {comment} */;")
        if attributes:
            joined = ", ".join(attributes)
            writer.raw(f"\t\t\tsettings = {{ATTRIBUTES = ({joined}, ); }};")
        writer.end()

    for path in app_swift:
        emit_build_file(build_file("app", str(path)), file_ref(str(path)), path.name)
    emit_build_file(build_file("app", "App/Assets.xcassets"), file_ref("App/Assets.xcassets"), "Assets.xcassets")
    emit_build_file(build_file("embed", "CountdownWidget.appex"), widget_product, "CountdownWidget.appex", ["RemoveHeadersOnCopy"])
    for path in widget_swift:
        emit_build_file(build_file("widget", str(path)), file_ref(str(path)), path.name)
    for path in test_sources:
        emit_build_file(build_file("test", str(path)), file_ref(str(path)), path.name)
    writer.lines.append("/* End PBXBuildFile section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXContainerItemProxy section */")
    for proxy, remote, info in (
        (widget_proxy, widget_target, "CountdownWidget"),
        (test_proxy, app_target, "CountdownTogether"),
    ):
        writer.begin(proxy, "PBXContainerItemProxy")
        writer.raw(f"\t\t\tcontainerPortal = {project_id} /* Project object */;")
        writer.raw("\t\t\tproxyType = 1;")
        writer.raw(f"\t\t\tremoteGlobalIDString = {remote};")
        writer.raw(f"\t\t\tremoteInfo = {info};")
        writer.end()
    writer.lines.append("/* End PBXContainerItemProxy section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXCopyFilesBuildPhase section */")
    writer.begin(embed_phase, "PBXCopyFilesBuildPhase")
    writer.raw("\t\t\tbuildActionMask = 2147483647;")
    writer.raw('\t\t\tdstPath = "";')
    writer.raw("\t\t\tdstSubfolderSpec = 13;")
    writer.raw("\t\t\tfiles = (")
    writer.raw(f"\t\t\t\t{build_file('embed', 'CountdownWidget.appex')} /* CountdownWidget.appex in Embed Foundation Extensions */,")
    writer.raw("\t\t\t);")
    writer.raw('\t\t\tname = "Embed Foundation Extensions";')
    writer.raw("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    writer.end()
    writer.lines.append("/* End PBXCopyFilesBuildPhase section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXFileReference section */")

    def emit_file(path: Path, file_type: str) -> None:
        writer.begin(file_ref(str(path)), "PBXFileReference")
        writer.raw(f"\t\t\tlastKnownFileType = {file_type};")
        writer.raw(f"\t\t\tpath = {quote(path.name)};")
        writer.raw('\t\t\tsourceTree = "<group>";')
        writer.end()

    type_by_suffix = {
        ".swift": "sourcecode.swift",
        ".plist": "text.plist.xml",
        ".entitlements": "text.plist.entitlements",
        ".py": "text.script.python",
        ".yml": "text.yaml",
    }
    seen: set[str] = set()
    grouped_paths: list[Path] = []
    for path in [*app_swift, *widget_sources, *test_sources, *extra_files]:
        key = str(path)
        if key in seen:
            continue
        seen.add(key)
        grouped_paths.append(path)
        if path.name.endswith(".xcassets"):
            emit_file(path, "folder.assetcatalog")
        else:
            emit_file(path, type_by_suffix.get(path.suffix, "text"))

    for product, product_type, name in (
        (app_product, "wrapper.application", "CountdownTogether.app"),
        (widget_product, "wrapper.app-extension", "CountdownWidget.appex"),
        (test_product, "wrapper.cfbundle", "CountdownTogetherTests.xctest"),
    ):
        writer.begin(product, "PBXFileReference")
        writer.raw(f"\t\t\texplicitFileType = {product_type};")
        writer.raw("\t\t\tincludeInIndex = 0;")
        writer.raw(f"\t\t\tpath = {quote(name)};")
        writer.raw("\t\t\tsourceTree = BUILT_PRODUCTS_DIR;")
        writer.end()
    writer.lines.append("/* End PBXFileReference section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXFrameworksBuildPhase section */")
    for phase in frameworks_phase.values():
        writer.begin(phase, "PBXFrameworksBuildPhase")
        writer.raw("\t\t\tbuildActionMask = 2147483647;")
        writer.raw("\t\t\tfiles = (")
        writer.raw("\t\t\t);")
        writer.raw("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        writer.end()
    writer.lines.append("/* End PBXFrameworksBuildPhase section */")
    writer.lines.append("")

    # Groups follow the directories on disk. A group's path is the folder name,
    # and file references inside it use only the filename.
    folders: dict[tuple[str, ...], list[Path]] = {}
    for path in grouped_paths:
        folders.setdefault(tuple(path.parts[:-1]), []).append(path)

    def group_id(parts: tuple[str, ...]) -> str:
        return main_group if not parts else oid("group", "/".join(parts))

    all_group_keys = {key for key in folders if key}
    for parts in list(all_group_keys):
        for length in range(1, len(parts)):
            all_group_keys.add(parts[:length])

    writer.lines.append("/* Begin PBXGroup section */")
    for parts in sorted(all_group_keys, key=lambda item: (len(item), item)):
        identifier = group_id(parts)
        writer.begin(identifier, "PBXGroup")
        writer.raw("\t\t\tchildren = (")
        child_folders = sorted(key for key in all_group_keys if len(key) == len(parts) + 1 and key[: len(parts)] == parts)
        for child in child_folders:
            writer.raw(f"\t\t\t\t{group_id(child)} /* {child[-1]} */,")
        for path in sorted(folders.get(parts, []), key=lambda item: item.name):
            writer.raw(f"\t\t\t\t{file_ref(str(path))} /* {path.name} */,")
        writer.raw("\t\t\t);")
        writer.raw(f"\t\t\tpath = {quote(parts[-1])};")
        writer.raw('\t\t\tsourceTree = "<group>";')
        writer.end()

    writer.begin(products_group, "PBXGroup")
    writer.raw("\t\t\tchildren = (")
    writer.raw(f"\t\t\t\t{app_product} /* CountdownTogether.app */,")
    writer.raw(f"\t\t\t\t{widget_product} /* CountdownWidget.appex */,")
    writer.raw(f"\t\t\t\t{test_product} /* CountdownTogetherTests.xctest */,")
    writer.raw("\t\t\t);")
    writer.raw("\t\t\tname = Products;")
    writer.raw('\t\t\tsourceTree = "<group>";')
    writer.end()

    writer.begin(main_group, "PBXGroup")
    writer.raw("\t\t\tchildren = (")
    for child in sorted(key for key in all_group_keys if len(key) == 1):
        writer.raw(f"\t\t\t\t{group_id(child)} /* {child[-1]} */,")
    root_files = sorted(folders.get((), []), key=lambda item: item.name)
    for path in root_files:
        writer.raw(f"\t\t\t\t{file_ref(str(path))} /* {path.name} */,")
    writer.raw(f"\t\t\t\t{products_group} /* Products */,")
    writer.raw("\t\t\t);")
    writer.raw('\t\t\tsourceTree = "<group>";')
    writer.end()
    writer.lines.append("/* End PBXGroup section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXNativeTarget section */")

    def emit_target(identifier: str, name: str, product_name: str, product_ref: str, product_type: str, phases: list[tuple[str, str]], deps: list[tuple[str, str]], config_list: str) -> None:
        writer.begin(identifier, "PBXNativeTarget")
        writer.raw(f"\t\t\tbuildConfigurationList = {config_list} /* Build configuration list for PBXNativeTarget \"{name}\" */;")
        writer.raw("\t\t\tbuildPhases = (")
        for phase, label in phases:
            writer.raw(f"\t\t\t\t{phase} /* {label} */,")
        writer.raw("\t\t\t);")
        writer.raw("\t\t\tbuildRules = (")
        writer.raw("\t\t\t);")
        writer.raw("\t\t\tdependencies = (")
        for dep, label in deps:
            writer.raw(f"\t\t\t\t{dep} /* {label} */,")
        writer.raw("\t\t\t);")
        writer.raw(f"\t\t\tname = {quote(name)};")
        writer.raw(f"\t\t\tproductName = {quote(product_name)};")
        writer.raw(f"\t\t\tproductReference = {product_ref} /* {product_name} */;")
        writer.raw(f"\t\t\tproductType = {quote(product_type)};")
        writer.end()

    emit_target(
        app_target,
        "CountdownTogether",
        "CountdownTogether.app",
        app_product,
        "com.apple.product-type.application",
        [
            (sources_phase["app"], "Sources"),
            (frameworks_phase["app"], "Frameworks"),
            (resources_phase["app"], "Resources"),
            (embed_phase, "Embed Foundation Extensions"),
        ],
        [(widget_dep, "CountdownWidget")],
        app_list,
    )
    emit_target(
        widget_target,
        "CountdownWidget",
        "CountdownWidget.appex",
        widget_product,
        "com.apple.product-type.app-extension",
        [
            (sources_phase["widget"], "Sources"),
            (frameworks_phase["widget"], "Frameworks"),
            (resources_phase["widget"], "Resources"),
        ],
        [],
        widget_list,
    )
    emit_target(
        test_target,
        "CountdownTogetherTests",
        "CountdownTogetherTests.xctest",
        test_product,
        "com.apple.product-type.bundle.unit-test",
        [
            (sources_phase["test"], "Sources"),
            (frameworks_phase["test"], "Frameworks"),
        ],
        [(test_dep, "CountdownTogether")],
        test_list,
    )
    writer.lines.append("/* End PBXNativeTarget section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXProject section */")
    writer.begin(project_id, "PBXProject")
    writer.raw("\t\t\tattributes = {")
    writer.raw("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    writer.raw("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    writer.raw("\t\t\t\tLastUpgradeCheck = 1600;")
    writer.raw("\t\t\t\tTargetAttributes = {")
    for target, test_host in ((app_target, None), (widget_target, None), (test_target, app_target)):
        writer.raw(f"\t\t\t\t\t{target} = {{")
        writer.raw("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
        writer.raw("\t\t\t\t\t\tProvisioningStyle = Automatic;")
        if test_host:
            writer.raw(f"\t\t\t\t\t\tTestTargetID = {test_host};")
        writer.raw("\t\t\t\t\t};")
    writer.raw("\t\t\t\t};")
    writer.raw("\t\t\t};")
    writer.raw(f"\t\t\tbuildConfigurationList = {project_list} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;")
    writer.raw('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    writer.raw("\t\t\tdevelopmentRegion = en;")
    writer.raw("\t\t\thasScannedForEncodings = 0;")
    writer.raw("\t\t\tknownRegions = (")
    writer.raw("\t\t\t\ten,")
    writer.raw("\t\t\t\tBase,")
    writer.raw("\t\t\t);")
    writer.raw(f"\t\t\tmainGroup = {main_group};")
    writer.raw(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
    writer.raw('\t\t\tprojectDirPath = "";')
    writer.raw('\t\t\tprojectRoot = "";')
    writer.raw("\t\t\ttargets = (")
    writer.raw(f"\t\t\t\t{app_target} /* CountdownTogether */,")
    writer.raw(f"\t\t\t\t{widget_target} /* CountdownWidget */,")
    writer.raw(f"\t\t\t\t{test_target} /* CountdownTogetherTests */,")
    writer.raw("\t\t\t);")
    writer.end()
    writer.lines.append("/* End PBXProject section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXResourcesBuildPhase section */")
    writer.begin(resources_phase["app"], "PBXResourcesBuildPhase")
    writer.raw("\t\t\tbuildActionMask = 2147483647;")
    writer.raw("\t\t\tfiles = (")
    writer.raw(f"\t\t\t\t{build_file('app', 'App/Assets.xcassets')} /* Assets.xcassets in Resources */,")
    writer.raw("\t\t\t);")
    writer.raw("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    writer.end()
    writer.begin(resources_phase["widget"], "PBXResourcesBuildPhase")
    writer.raw("\t\t\tbuildActionMask = 2147483647;")
    writer.raw("\t\t\tfiles = (")
    writer.raw("\t\t\t);")
    writer.raw("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    writer.end()
    writer.lines.append("/* End PBXResourcesBuildPhase section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXSourcesBuildPhase section */")

    def emit_sources(phase: str, scope: str, paths: list[Path]) -> None:
        writer.begin(phase, "PBXSourcesBuildPhase")
        writer.raw("\t\t\tbuildActionMask = 2147483647;")
        writer.raw("\t\t\tfiles = (")
        for path in paths:
            writer.raw(f"\t\t\t\t{build_file(scope, str(path))} /* {path.name} in Sources */,")
        writer.raw("\t\t\t);")
        writer.raw("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
        writer.end()

    emit_sources(sources_phase["app"], "app", app_swift)
    emit_sources(sources_phase["widget"], "widget", widget_swift)
    emit_sources(sources_phase["test"], "test", test_sources)
    writer.lines.append("/* End PBXSourcesBuildPhase section */")
    writer.lines.append("")

    writer.lines.append("/* Begin PBXTargetDependency section */")
    for dep, proxy, target, name in (
        (widget_dep, widget_proxy, widget_target, "CountdownWidget"),
        (test_dep, test_proxy, app_target, "CountdownTogether"),
    ):
        writer.begin(dep, "PBXTargetDependency")
        writer.raw(f"\t\t\ttarget = {target} /* {name} */;")
        writer.raw(f"\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;")
        writer.end()
    writer.lines.append("/* End PBXTargetDependency section */")
    writer.lines.append("")

    project_common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ANALYZER_NONNULL": "YES",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_ENABLE_OBJC_WEAK": "YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES",
        "CLANG_WARN_BOOL_CONVERSION": "YES",
        "CLANG_WARN_COMMA": "YES",
        "CLANG_WARN_CONSTANT_CONVERSION": "YES",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
        "CLANG_WARN_EMPTY_BODY": "YES",
        "CLANG_WARN_ENUM_CONVERSION": "YES",
        "CLANG_WARN_INFINITE_RECURSION": "YES",
        "CLANG_WARN_INT_CONVERSION": "YES",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES",
        "CLANG_WARN_STRICT_PROTOTYPES": "YES",
        "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "CLANG_WARN_UNUSED_FUNCTION": "YES",
        "CLANG_WARN_UNUSED_VARIABLE": "YES",
        "COPY_PHASE_STRIP": "NO",
        "ENABLE_STRICT_OBJC_MSGSEND": "YES",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "GCC_NO_COMMON_BLOCKS": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "SDKROOT": "iphoneos",
        "STRING_CATALOG_GENERATE_SYMBOLS": "NO",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    debug_project = {
        **project_common,
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_TESTABILITY": "YES",
        "GCC_DYNAMIC_NO_PIC": "NO",
        "GCC_OPTIMIZATION_LEVEL": "0",
        "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH": "YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    }
    release_project = {
        **project_common,
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_NS_ASSERTIONS": "NO",
        "MTL_ENABLE_DEBUG_INFO": "NO",
        "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O",
        "VALIDATE_PRODUCT": "YES",
    }

    app_settings = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "ENABLE_PREVIEWS": "YES",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "App/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.countdowntogether.app",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    widget_settings = {
        "APPLICATION_EXTENSION_API_ONLY": "YES",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": "Widget/Info.plist",
        "LD_RUNPATH_SEARCH_PATHS": [
            "$(inherited)",
            "@executable_path/Frameworks",
            "@executable_path/../../Frameworks",
        ],
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.countdowntogether.app.widget",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SKIP_INSTALL": "YES",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
    }
    test_settings = {
        "BUNDLE_LOADER": "$(TEST_HOST)",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "1",
        "GENERATE_INFOPLIST_FILE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.countdowntogether.app.tests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SDKROOT": "iphoneos",
        "SWIFT_EMIT_LOC_STRINGS": "NO",
        "SWIFT_VERSION": "5.0",
        "TARGETED_DEVICE_FAMILY": "1",
        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/CountdownTogether.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CountdownTogether",
    }

    config_values = {
        ("project", "Debug"): debug_project,
        ("project", "Release"): release_project,
        ("app", "Debug"): app_settings,
        ("app", "Release"): app_settings,
        ("widget", "Debug"): widget_settings,
        ("widget", "Release"): widget_settings,
        ("test", "Debug"): test_settings,
        ("test", "Release"): test_settings,
    }

    writer.lines.append("/* Begin XCBuildConfiguration section */")
    for (kind, name), identifier in configs.items():
        writer.begin(identifier, "XCBuildConfiguration")
        writer.raw(f"\t\t\tbuildSettings = {{")
        writer.lines.extend(settings_block(config_values[(kind, name)], indent=4))
        writer.raw("\t\t\t};")
        writer.raw(f"\t\t\tname = {name};")
        writer.end()
    writer.lines.append("/* End XCBuildConfiguration section */")
    writer.lines.append("")

    writer.lines.append("/* Begin XCConfigurationList section */")

    def emit_list(identifier: str, kind: str, comment: str) -> None:
        writer.begin(identifier, "XCConfigurationList")
        writer.raw("\t\t\tbuildConfigurations = (")
        writer.raw(f"\t\t\t\t{configs[(kind, 'Debug')]} /* Debug */,")
        writer.raw(f"\t\t\t\t{configs[(kind, 'Release')]} /* Release */,")
        writer.raw("\t\t\t);")
        writer.raw("\t\t\tdefaultConfigurationIsVisible = 0;")
        writer.raw("\t\t\tdefaultConfigurationName = Release;")
        writer.end()

    emit_list(project_list, "project", "project")
    emit_list(app_list, "app", "app")
    emit_list(widget_list, "widget", "widget")
    emit_list(test_list, "test", "test")
    writer.lines.append("/* End XCConfigurationList section */")

    writer.lines.append("\t};")
    writer.lines.append(f"\trootObject = {project_id} /* Project object */;")
    writer.lines.append("}")
    writer.lines.append("")

    text = "\n".join(writer.lines)
    XCODEPROJ.mkdir(parents=True, exist_ok=True)
    (XCODEPROJ / "project.pbxproj").write_text(text, encoding="utf-8")
    scheme_dir = XCODEPROJ / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / "CountdownTogether.xcscheme").write_text(scheme(app_target, widget_target, test_target), encoding="utf-8")
    print(f"Wrote {XCODEPROJ / 'project.pbxproj'}")


def scheme(app_target: str, widget_target: str, test_target: str) -> str:
    def entry(target: str, name: str, product: str, testing: str, running: str, profiling: str, archiving: str, analyzing: str) -> str:
        return f"""
         <BuildActionEntry
            buildForTesting = "{testing}"
            buildForRunning = "{running}"
            buildForProfiling = "{profiling}"
            buildForArchiving = "{archiving}"
            buildForAnalyzing = "{analyzing}">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "{product}"
               BlueprintName = "{name}"
               ReferencedContainer = "container:CountdownTogether.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>"""

    app_ref = f"""<BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target}"
               BuildableName = "CountdownTogether.app"
               BlueprintName = "CountdownTogether"
               ReferencedContainer = "container:CountdownTogether.xcodeproj">
            </BuildableReference>"""
    test_ref = f"""<BuildableReference
                  BuildableIdentifier = "primary"
                  BlueprintIdentifier = "{test_target}"
                  BuildableName = "CountdownTogetherTests.xctest"
                  BlueprintName = "CountdownTogetherTests"
                  ReferencedContainer = "container:CountdownTogether.xcodeproj">
               </BuildableReference>"""
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1600"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>{entry(app_target, "CountdownTogether", "CountdownTogether.app", "YES", "YES", "YES", "YES", "YES")}
{entry(widget_target, "CountdownWidget", "CountdownWidget.appex", "YES", "YES", "NO", "NO", "NO")}
{entry(test_target, "CountdownTogetherTests", "CountdownTogetherTests.xctest", "YES", "NO", "NO", "NO", "NO")}
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            {test_ref}
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {app_ref}
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         {app_ref}
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


if __name__ == "__main__":
    main()
