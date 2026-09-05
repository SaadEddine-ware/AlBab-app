import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from PySide6.QtCore import QUrl, QTimer
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from core.math_engine import MathEngine

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
math_engine = MathEngine()
engine.rootContext().setContextProperty("MathEngine", math_engine)

qml = os.path.join(os.path.dirname(__file__), "test_math.qml")
engine.load(QUrl.fromLocalFile(qml))

def check():
    root_objs = engine.rootObjects()
    print(f"Root objects: {len(root_objs)}", flush=True)
    if root_objs:
        r = root_objs[0].property("result")
        print(f"result='{r}'", flush=True)
    app.quit()

QTimer.singleShot(1000, check)
app.exec()
