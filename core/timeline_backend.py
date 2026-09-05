import json
from PySide6.QtCore import QObject, Slot

SAMPLE_TIMELINES: dict = {
    "world_wars": {
        "name": "World Wars (1914-1945)",
        "events": [
            {"id": "e1", "date": "1914-06-28", "title": "Assassination of Archduke Franz Ferdinand",
             "desc": "Heir to Austria-Hungary throne assassinated in Sarajevo, triggering WWI",
             "category": "Politics", "color": "#B48250", "importance": 5},
            {"id": "e2", "date": "1914-07-28", "title": "Austria-Hungary declares war on Serbia",
             "desc": "Start of World War I", "category": "War", "color": "#E91E63", "importance": 5},
            {"id": "e3", "date": "1917-04-06", "title": "US enters WWI",
             "desc": "United States declares war on Germany", "category": "War", "color": "#E91E63", "importance": 4},
            {"id": "e4", "date": "1918-11-11", "title": "Armistice signed — WWI ends",
             "desc": "Ceasefire on the Western Front", "category": "Politics", "color": "#B48250", "importance": 5},
            {"id": "e5", "date": "1919-06-28", "title": "Treaty of Versailles",
             "desc": "Formally ended WWI, imposed heavy reparations on Germany",
             "category": "Politics", "color": "#B48250", "importance": 4},
            {"id": "e6", "date": "1929-10-29", "title": "Wall Street Crash",
             "desc": "Stock market collapse triggering the Great Depression",
             "category": "Economy", "color": "#4CAF50", "importance": 4},
            {"id": "e7", "date": "1933-01-30", "title": "Hitler becomes Chancellor",
             "desc": "Adolf Hitler appointed Chancellor of Germany", "category": "Politics", "color": "#B48250", "importance": 5},
            {"id": "e8", "date": "1939-09-01", "title": "Germany invades Poland",
             "desc": "Start of World War II in Europe", "category": "War", "color": "#E91E63", "importance": 5},
            {"id": "e9", "date": "1941-12-07", "title": "Attack on Pearl Harbor",
             "desc": "Japan attacks US naval base; US enters WWII", "category": "War", "color": "#E91E63", "importance": 5},
            {"id": "e10", "date": "1945-05-08", "title": "VE Day",
             "desc": "Germany surrenders; WWII in Europe ends", "category": "War", "color": "#E91E63", "importance": 5},
            {"id": "e11", "date": "1945-08-06", "title": "Atomic bombing of Hiroshima",
             "desc": "First atomic bomb used in warfare", "category": "War", "color": "#E91E63", "importance": 5},
            {"id": "e12", "date": "1945-09-02", "title": "Japan surrenders — WWII ends",
             "desc": "Formal surrender aboard USS Missouri", "category": "Politics", "color": "#B48250", "importance": 5}
        ]
    },
    "ancient": {
        "name": "Ancient Civilizations (3000 BCE - 500 CE)",
        "events": [
            {"id": "a1", "date": "-3000", "title": "Sumerian civilization emerges",
             "desc": "First cities in Mesopotamia, invention of cuneiform writing",
             "category": "Culture", "color": "#2196F3", "importance": 5},
            {"id": "a2", "date": "-2560", "title": "Great Pyramid of Giza completed",
             "desc": "Built for Pharaoh Khufu, tallest man-made structure for 3800 years",
             "category": "Culture", "color": "#2196F3", "importance": 4},
            {"id": "a3", "date": "-1792", "title": "Code of Hammurabi",
             "desc": "Babylonian law code, one of the earliest written legal codes",
             "category": "Politics", "color": "#B48250", "importance": 4},
            {"id": "a4", "date": "-550", "title": "Persian Empire founded",
             "desc": "Cyrus the Great establishes Achaemenid Empire",
             "category": "Politics", "color": "#B48250", "importance": 4},
            {"id": "a5", "date": "-508", "title": "Athenian democracy established",
             "desc": "Cleisthenes reforms create world's first democracy",
             "category": "Politics", "color": "#B48250", "importance": 5},
            {"id": "a6", "date": "-338", "title": "Alexander the Great conquers Greece",
             "desc": "Leads campaigns across Persia to India", "category": "War", "color": "#E91E63", "importance": 4},
            {"id": "a7", "date": "-221", "title": "Qin unifies China",
             "desc": "First Emperor unifies warring states, starts Great Wall",
             "category": "Politics", "color": "#B48250", "importance": 4},
            {"id": "a8", "date": "-27", "title": "Roman Empire begins",
             "desc": "Augustus becomes first Roman emperor", "category": "Politics", "color": "#B48250", "importance": 5},
            {"id": "a9", "date": "476", "title": "Fall of Western Roman Empire",
             "desc": "Romulus Augustulus deposed, traditional end of ancient era",
             "category": "War", "color": "#E91E63", "importance": 5}
        ]
    }
}


class TimelineBackend(QObject):
    def __init__(self):
        super().__init__()
        self._timeline = {"name": "Untitled", "events": []}
        self._next_id = 0

    def _new_id(self):
        self._next_id += 1
        return f"e{self._next_id}"

    def _emit(self):
        return json.dumps(self._timeline)

    @Slot(result=str)
    def newTimeline(self):
        self._timeline = {"name": "Untitled", "events": []}
        self._next_id = 0
        return self._emit()

    @Slot(str, result=str)
    def loadSample(self, name):
        if name in SAMPLE_TIMELINES:
            self._timeline = json.loads(json.dumps(SAMPLE_TIMELINES[name]))
            max_id = max((int(ev["id"][1:]) for ev in self._timeline["events"] if ev["id"].startswith("e") and ev["id"][1:].isdigit()), default=0)
            self._next_id = max_id
            return self._emit()
        return self._emit()

    @Slot(str, str, str, str, str, int, result=str)
    def addEvent(self, date, title, desc, category, color, importance):
        eid = self._new_id()
        self._timeline["events"].append({
            "id": eid, "date": date, "title": title, "desc": desc,
            "category": category, "color": color, "importance": importance
        })
        return self._emit()

    @Slot(str, str, str, str, str, str, str, int, result=str)
    def updateEvent(self, eid, date, title, desc, category, color, importance):
        for ev in self._timeline["events"]:
            if ev["id"] == eid:
                ev.update({"date": date, "title": title, "desc": desc,
                          "category": category, "color": color, "importance": importance})
                break
        return self._emit()

    @Slot(str, result=str)
    def setEvents(self, jsonStr):
        try:
            arr = json.loads(jsonStr)
            events = []
            for i, ev in enumerate(arr):
                events.append({
                    "id": f"e{i}", "date": str(ev.get("start", 1900)),
                    "title": ev.get("title", "Event"),
                    "desc": ev.get("description", ""),
                    "category": ev.get("category", "general"),
                    "color": ev.get("color", "#B48250"), "importance": ev.get("importance", 3),
                })
            self._timeline["events"] = events
            return json.dumps({"ok": True, "count": len(events)})
        except Exception as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def removeEvent(self, eid):
        self._timeline["events"] = [ev for ev in self._timeline["events"] if ev["id"] != eid]
        return self._emit()

    @Slot(str, result=str)
    def getTimelineByName(self, name):
        if name in SAMPLE_TIMELINES:
            tl = SAMPLE_TIMELINES[name]
            out = []
            for ev in tl["events"]:
                yyyy = self._parse_date(ev["date"])[0]
                out.append({
                    "title": ev["title"], "start": yyyy, "end": yyyy,
                    "description": ev.get("desc", ""),
                    "category": ev.get("category", "general").lower()
                })
            return json.dumps(out)
        return "[]"

    @Slot(result=str)
    def getTimeline(self):
        return self._emit()

    @Slot(result=str)
    def getSampleNames(self):
        return json.dumps(list(SAMPLE_TIMELINES.keys()))

    @Slot(str, result=str)
    def setName(self, name):
        self._timeline["name"] = name
        return self._emit()

    def _parse_date(self, date_str: str) -> tuple:
        try:
            parts = date_str.split("-")
            y = int(parts[0])
            m = int(parts[1]) if len(parts) > 1 else 1
            d = int(parts[2]) if len(parts) > 2 else 1
            return y, m, d
        except (ValueError, IndexError):
            return 0, 1, 1
