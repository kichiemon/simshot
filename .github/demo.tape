# simshot demo recording (vhs)
#
# Renders assets/demo.gif for the README.
#
# Prerequisites:
#   1. brew install vhs
#   2. swift build -c release        # binary at ./.build/release/simshot
#   3. export PATH="$PWD/.build/release:$PATH"
#
# Render:
#   vhs .github/demo.tape

Output assets/demo.gif
Set FontSize 18
Set Width 1240
Set Height 640
Set Padding 24
Set Framerate 30
Set PlaybackSpeed 1.5
Set TypingSpeed 25ms

Type "simshot --help"
Enter
Sleep 2s

Type "simshot devices"
Enter
Sleep 3s

Type "simshot doctor"
Enter
Sleep 3s

Type "simshot shoot --help"
Enter
Sleep 3s
