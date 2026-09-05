import sys, os
from PySide6.QtCore import QUrl, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

os.environ['QT_QPA_PLATFORM'] = 'offscreen'

# Redirect stderr to capture console.log
import io
old_stderr = sys.stderr
sys.stderr = io.StringIO()

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()

engine.addImportPath('E:/albab-app/ui')
result = engine.load(QUrl.fromLocalFile('E:/albab-app/ui/main.qml'))

QTimer.singleShot(1000, app.quit)
app.exec()

# Get stderr output
stderr_output = sys.stderr.getvalue()
sys.stderr = old_stderr

# Write to file
with open('E:/albab-app/debug_stderr.txt', 'w') as f:
    f.write(stderr_output)

print('Root objects:', len(engine.rootObjects()))
print('Stderr length:', len(stderr_output))
if 'earth' in stderr_output.lower() or 'texture' in stderr_output.lower() or 'image' in stderr_output.lower():
    print('Found texture-related output!')
    for line in stderr_output.split('\n'):
        if 'earth' in line.lower() or 'texture' in line.lower() or 'image' in line.lower():
            print('  ', line[:200])
