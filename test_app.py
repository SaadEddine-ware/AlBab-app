import sys, os
from PySide6.QtCore import QUrl, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
engine.setOutputWarningsToStandardError(True)

logs = []
def on_warning(msg):
    logs.append(str(msg))

engine.warnings.connect(on_warning)

engine.addImportPath('E:/albab-app/ui')
result = engine.load(QUrl.fromLocalFile('E:/albab-app/ui/main.qml'))

print('Load result:', result)
print('Root objects:', len(engine.rootObjects()))

# Wait for timers to fire
QTimer.singleShot(200, app.quit)
app.exec()

# Write logs to file
with open('E:/albab-app/debug_logs.txt', 'w') as f:
    for log in logs:
        f.write(log + '\n')

print('Logs written to debug_logs.txt')
print('Total warnings:', len(logs))
