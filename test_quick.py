import sys, os
from PySide6.QtCore import QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

os.environ['QT_QPA_PLATFORM'] = 'offscreen'
app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()

engine.addImportPath('E:/albab-app/ui')
result = engine.load(QUrl.fromLocalFile('E:/albab-app/ui/main.qml'))
print('Root objects:', len(engine.rootObjects()))
app.quit()
