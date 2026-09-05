from __future__ import annotations
import json
from PySide6.QtCore import QObject, Slot

class GraphAlgo:
    def __init__(self, data: list):
        self.data = data
        self.n = len(data) if data else 0

    def connectivity(self) -> tuple:
        if self.n == 0:
            return False, []
        n = self.n
        visited = [False] * n
        stack = [0]
        while stack:
            v = stack.pop()
            if not visited[v]:
                visited[v] = True
                for u in range(n):
                    if self.data[v][u] != 0 and not visited[u]:
                        stack.append(u)
        return all(visited), []

    def connected_components(self) -> list:
        if self.n == 0:
            return []
        n = self.n
        visited = [False] * n
        components = []
        for i in range(n):
            if not visited[i]:
                comp = []
                stack = [i]
                while stack:
                    v = stack.pop()
                    if not visited[v]:
                        visited[v] = True
                        comp.append(v)
                        for u in range(n):
                            if self.data[v][u] != 0 and not visited[u]:
                                stack.append(u)
                components.append(comp)
        return components

    def is_bipartite(self) -> bool:
        if self.n == 0:
            return True
        n = self.n
        color = [-1] * n
        for start in range(n):
            if color[start] == -1:
                color[start] = 0
                queue = [start]
                while queue:
                    v = queue.pop(0)
                    for u in range(n):
                        if self.data[v][u] != 0:
                            if color[u] == -1:
                                color[u] = 1 - color[v]
                                queue.append(u)
                            elif color[u] == color[v]:
                                return False
        return True

    def shortest_path(self, start: int, end: int) -> list | None:
        if self.n == 0:
            return None
        if not (0 <= start < self.n) or not (0 <= end < self.n):
            return None
        n = self.n
        dist = [float('inf')] * n
        prev = [None] * n
        dist[start] = 0
        unvisited = set(range(n))
        while unvisited:
            u = min(unvisited, key=lambda x: dist[x])
            if dist[u] == float('inf'):
                break
            unvisited.remove(u)
            if u == end:
                break
            for v in range(n):
                w = self.data[u][v]
                if w > 0 and v in unvisited:
                    alt = dist[u] + w
                    if alt < dist[v]:
                        dist[v] = alt
                        prev[v] = u
        if prev[end] is None and start != end:
            return None
        path = []
        v = end
        while v is not None:
            path.append(v)
            v = prev[v]
        path.reverse()
        return path

    def mst_prim(self) -> list:
        if self.n == 0:
            return []
        n = self.n
        INF = float('inf')
        key = [INF] * n
        parent = [None] * n
        mst_set = [False] * n
        key[0] = 0
        for _ in range(n):
            u = -1
            min_val = INF
            for v in range(n):
                if not mst_set[v] and key[v] < min_val:
                    min_val = key[v]
                    u = v
            if u == -1:
                break
            mst_set[u] = True
            for v in range(n):
                w = self.data[u][v]
                if w > 0 and not mst_set[v] and w < key[v]:
                    key[v] = w
                    parent[v] = u
        edges = []
        for i in range(1, n):
            if parent[i] is not None:
                edges.append([parent[i], i])
        return edges

class GraphBackend(QObject):
    def __init__(self):
        super().__init__()

    @Slot(str, result=str)
    def connectivity(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            algo = GraphAlgo(data)
            connected, _ = algo.connectivity()
            return json.dumps({"ok": True, "connected": connected})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def connectedComponents(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            algo = GraphAlgo(data)
            comps = algo.connected_components()
            return json.dumps({"ok": True, "components": comps})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def bipartite(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            algo = GraphAlgo(data)
            return json.dumps({"ok": True, "bipartite": algo.is_bipartite()})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, int, int, result=str)
    def shortestPath(self, json_data: str, start: int, end: int) -> str:
        try:
            data = json.loads(json_data)
            algo = GraphAlgo(data)
            path = algo.shortest_path(start, end)
            if path is None:
                return json.dumps({"ok": False, "error": "No path found"})
            return json.dumps({"ok": True, "path": path})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})

    @Slot(str, result=str)
    def mst(self, json_data: str) -> str:
        try:
            data = json.loads(json_data)
            algo = GraphAlgo(data)
            edges = algo.mst_prim()
            return json.dumps({"ok": True, "edges": edges})
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            return json.dumps({"ok": False, "error": str(e)})
