enum Help {
    static let main = """
        simshot — App Store screenshot capture CLI (simctl only, no XCUITest)

        USAGE:
          simshot shoot <options>
          simshot devices
          simshot doctor
          simshot init [--yes] [--output <path>]
          simshot verify [dir] [--devices <list>] [--langs <list>] [--json]
          simshot version
          simshot help

        COMMANDS:
          shoot       Build the app, boot simulators, and capture App Store screenshots.
          devices     List available simulators (name + UDID).
          doctor      Diagnose the local Xcode / simulator environment (exit 1 if broken).
          init        Generate a commented simshot.yml config scaffold.
          verify      Check captured screenshots against App Store requirements (exit 1 on problems).
          version     Print the version.
          help        Show this help.

        Run `simshot shoot --help` for all shoot options.
        """

    static let doctor = """
        simshot doctor — diagnose the local environment

        Checks xcode-select, Xcode, simctl, iOS runtimes, and available
        simulators. Exits 0 when everything looks good, 1 when a check fails.

        USAGE:
          simshot doctor
        """

    static let initHelp = """
        simshot init — generate a commented simshot.yml config scaffold

        USAGE:
          simshot init [--yes] [--output <path>]

        OPTIONS:
          --yes, -y          Use default placeholder values without prompting.
          --output <path>    Output file (default: simshot.yml)
          --help, -h         Show this help.
        """

    static let verify = """
        simshot verify — check captured screenshots against App Store requirements

        Walks an output tree produced by `simshot shoot` and reports anything that
        App Store Connect would reject or ignore:

        - dimensions that are not an accepted App Store screenshot size
        - an alpha channel (rejected at upload)
        - mixed sizes inside one device/language folder
        - empty or missing device/language folders

        `raw/` (the untouched simctl captures) is skipped: verify inspects the
        App Store copies, so run shoot with `--resize` first.

        USAGE:
          simshot verify [dir] [options]

        ARGUMENTS:
          dir                Output directory to inspect (default: appstore)

        OPTIONS:
          --devices <list>   Require these device folders (default: whatever exists on disk)
          --langs <list>     Require these language folders (default: whatever exists on disk)
          --json             Print a machine-readable JSON report
          --help, -h         Show this help.

        EXIT CODES:
          0  every checked screenshot is App Store-ready
          1  at least one problem was found (details on stderr)

        EXAMPLE:
          simshot shoot --project MyApp.xcodeproj --scheme MyApp \\
            --bundle-id com.example.myapp --devices iphone-17-pro-max \\
            --langs ja,en --scenes home,detail --resize
          simshot verify appstore --devices iphone-17-pro-max --langs ja,en
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
          --bundle-id <id>               App bundle identifier (e.g. com.example.myapp)
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
          simshot shoot --project MyApp.xcodeproj --scheme MyApp \\
            --bundle-id com.example.myapp \\
            --devices iphone-17-pro-max,ipad-pro-13 \\
            --langs ja,en --shots shots.json --resize

        OUTPUT LAYOUT:
          appstore/raw/<device>/<lang>/NN_name.png     raw simctl captures
          appstore/<device>/<lang>/NN_name.png         resized App Store copies (--resize)
        """
}
