pragma Singleton
import QtQuick

QtObject {
    property bool darkMode: false

    readonly property color pageBg:           darkMode ? "#1A1A1A" : "#F5F0EB"
    readonly property color sidebarBg:        "#1A1A1A"
    readonly property color sidebarHover:     "#12FFFFFF"
    readonly property color sidebarActiveBg:  "#0AFFFFFF"

    readonly property color glassBase:        darkMode ? "#33FFFFFF" : "#99FFFFFF"
    readonly property color glassBorder:      darkMode ? "#1AFFFFFF" : "#0F000000"
    readonly property color glassHover:       darkMode ? "#44FFFFFF" : "#C7FFFFFF"

    readonly property color textPrimary:      darkMode ? "#E0E0E0" : "#1A1A1A"
    readonly property color textSecondary:    darkMode ? "#A0A0A0" : "#5A5550"
    readonly property color textMuted:        darkMode ? "#707070" : "#8A8580"
    readonly property color textSidebar:      "#80FFFFFF"
    readonly property color textSidebarActive:"#FFFFFF"

    readonly property color accentCopper:     "#B48250"
    readonly property color accentCopperDark: "#8B6438"
    readonly property color accentGreen:      "#4CAF50"
    readonly property color accentOrange:     "#FF9800"
    readonly property color accentRed:        "#EF5350"
    readonly property color accentBlue:       "#448AFF"

    readonly property color errorBg:          darkMode ? "#3E1A1A" : "#FFEBEE"
    readonly property color errorText:        darkMode ? "#EF9A9A" : "#C62828"
    readonly property color successBg:        darkMode ? "#1A3E1A" : "#E8F5E9"
    readonly property color successText:      darkMode ? "#A5D6A7" : "#2E7D32"
    readonly property color warningBg:        darkMode ? "#3E2E1A" : "#FFF3E0"
    readonly property color warningText:      darkMode ? "#FFCC80" : "#E65100"

    readonly property color inputBg:          darkMode ? "#2A2A2A" : "#8CFFFFFF"
    readonly property color cardBg:           darkMode ? "#2A2A2A" : "#8CFFFFFF"
    readonly property color pageCardBg:       darkMode ? "#252525" : "#FFFFFF"
    readonly property color divider:          darkMode ? "#333333" : "#0A000000"

    readonly property color shadowLight:      darkMode ? "#0A000000" : "#0F000000"
    readonly property color shadowMedium:     darkMode ? "#15000000" : "#1A000000"

    readonly property color inactiveBtn:      darkMode ? "#3A3A3A" : "#D8D0C8"
    readonly property color inactiveBtnDark:  darkMode ? "#2A2A2A" : "#D0C8B8"
    readonly property color btnDefault:       darkMode ? "#333333" : "#FFFFFF"
    readonly property color clearBtn:         darkMode ? "#4A2020" : "#FFE0D0"
    readonly property color negateBtn:        darkMode ? "#3A3028" : "#E8E0D8"
    readonly property color sciBtn:           darkMode ? "#353028" : "#E4DED8"
    readonly property color altRowBg:         darkMode ? "#252525" : "#F8F5F0"
    readonly property color canvasBg:         darkMode ? "#1E1E1E" : "#F0ECE6"
    readonly property color cellBg:           darkMode ? "#2A2A2A" : "#F0F0F0"
    readonly property color cellBorder:       darkMode ? "#444444" : "#CCC"
    readonly property color resultBg:         darkMode ? "#252525" : "#D0FFFFFF"
    readonly property color statusBarBg:      darkMode ? "#222222" : "#73FFFFFF"
    readonly property color navBarBg:         darkMode ? "#1A1A1A" : "#1A1A1A"
    readonly property color navInactive:      darkMode ? "#3A3A3A" : "#3A3A3A"
    readonly property color overlayBg:        darkMode ? "#CC111111" : "#CC000000"
    readonly property color chipBg:           darkMode ? "#333333" : "#D8D0C8"
    readonly property color contentBg:        darkMode ? "#222222" : "#FFFFFF"
    readonly property color placeholderText:  darkMode ? "#606060" : "#B5AFAA"
    readonly property color hudText:          darkMode ? "#909090" : "#888080"
    readonly property color strokeColor:      darkMode ? "#40FFFFFF" : "#2A000000"
    readonly property color wireframeNormal:  darkMode ? "#808080" : "#7A7575"
    readonly property color selectHighlight:  "#B48250"

    readonly property color catMilitary:      "#D44942"
    readonly property color catPolitical:     "#4A90D9"
    readonly property color catCultural:      "#50B87A"
    readonly property color catGeneral:       "#B48250"

    readonly property int radiusSm:   6
    readonly property int radiusMd:   10
    readonly property int radiusLg:   14
    readonly property int radiusFull: 18

    readonly property int sidebarExpanded:  240
    readonly property int sidebarCollapsed: 68

    readonly property int spacingXs:  6
    readonly property int spacingSm:  10
    readonly property int spacingMd:  18
    readonly property int spacingLg:  28
    readonly property int spacingXl:  40

    readonly property int fontSizeXs:  11
    readonly property int fontSizeSm:  13
    readonly property int fontSizeMd:  15
    readonly property int fontSizeLg:  17
    readonly property int fontSizeXl:  24
    readonly property int fontSizeXxl: 32

    readonly property string fontFamily: "Segoe UI, 'Helvetica Neue', Arial, sans-serif"
    readonly property string fontMono:   "Consolas, 'Courier New', monospace"
}
