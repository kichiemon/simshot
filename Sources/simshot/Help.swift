enum Help {
    static let main = """
    simshot — App Store screenshot capture CLI (simctl only, no XCUITest)

    USAGE:
      simshot shoot <options>
      simshot devices
      simshot version
      simshot help

    COMMANDS:
      shoot       Build the app, boot simulators, and capture App Store screenshots.
      devices     List available simulators (name + UDID).
      version     Print the version.
      help        Show this help.

    Run `simshot shoot --help` for all shoot options.
    """

    static let shoot = """
    simshot shoot — capture App Store screenshots

    USAGE:
      simshot shoot --project <xcodeproj> --scheme <name> --bundle-id <id> \\
                   --devices <list> [options]

    BUILD:
      --project <path.xcodeproj>     Xcode project to build (mutually exclusive with --workspace)
      --workspace <path.xcworkspace> Xcode workspace to build
      --scheme <name>                Scheme to build
      --app-path <path.app>          Skip building; use an existing .app bundle

    REQUIRED:
      --bundle-id <id>               App bundle identifier (e.g. dev.kichiemon.kanapp)
      --devices <list>               Comma-separated simulator names or UDIDs
                                     (e.g. iphone-17-pro-max,ipad-pro-13)

    SHOTS:
      --shots <config.json>          Shot config file ({ "shots": [...] }) — full control
      --scenes <list>                Shortcut: one shot per scene, e.g. home,trace,notebook
      --wait <secs>                  Default settle time per shot for --scenes (default: 6)

    LOCALIZATION:
      --langs <list>                 Comma-separated languages (default: en), e.g. ja,en
      --locales <map>                Language→locale overrides, e.g. ja=ja_JP,en=en_US

    OUTPUT:
      --output <dir>                 Output directory (default: appstore)
      --resize                       Also write App Store-ready resized copies (alpha removed)
      --derived-data <dir>           DerivedData path (default: ~/.simshot/DerivedData)

    SIMULATOR:
      --timeout <secs>               Timeout for external commands (default: 300)
      --status-bar-time <t>          Status bar clock (default: 9:41)
      --status-bar-battery <n>       Status bar battery % (default: 100)
      --no-ui-testing                Do not pass --ui-testing to the app
      --no-clean                     Do not uninstall the app before installing
      --keep-running                 Do not shut down simulators afterwards

    MISC:
      --verbose, -v                  Verbose output
      --help, -h                     Show this help

    EXAMPLE:
      simshot shoot --project Kanapp.xcodeproj --scheme Kanapp \\
        --bundle-id dev.kichiemon.kanapp \\
        --devices iphone-17-pro-max,ipad-pro-13 \\
        --langs ja,en --shots shots.json --resize

    OUTPUT LAYOUT:
      appstore/raw/<device>/<lang>/NN_name.png     raw simctl captures
      appstore/<device>/<lang>/NN_name.png         resized App Store copies (--resize)
    """
}
