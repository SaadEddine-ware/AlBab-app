import json
import math
import os
import tempfile
import numpy as np
import trimesh
from PySide6.QtCore import QObject, Slot

_GEOM_TEMP = os.path.join(tempfile.gettempdir(), "albab_mesh_import")
os.makedirs(_GEOM_TEMP, exist_ok=True)


class MeshBackend(QObject):
    def __init__(self):
        super().__init__()
        self._objects: dict = {}
        self._next_id = 0
        self._default_color_idx = 0
        self._colors = [
            "#B48250", "#4CAF50", "#2196F3", "#E91E63",
            "#9C27B0", "#FF9800", "#00BCD4", "#F44336"
        ]

    def _new_id(self) -> str:
        self._next_id += 1
        return f"obj_{self._next_id}"

    def _next_color(self) -> str:
        c = self._colors[self._default_color_idx % len(self._colors)]
        self._default_color_idx += 1
        return c

    def _face_normals(self, verts: list, faces: list) -> list:
        normals = []
        for f in faces:
            v0, v1, v2 = verts[f[0]], verts[f[1]], verts[f[2]]
            e1 = np.array(v1) - np.array(v0)
            e2 = np.array(v2) - np.array(v0)
            n = np.cross(e1, e2)
            d = np.linalg.norm(n)
            if d > 1e-10:
                n = n / d
            normals.append(n.tolist())
        return normals

    def _mesh_from_geom(self, geom: dict) -> trimesh.Trimesh:
        return trimesh.Trimesh(
            vertices=np.array(geom["vertices"]),
            faces=np.array(geom["faces"])
        )

    def _mesh_to_geom(self, mesh: trimesh.Trimesh) -> dict:
        verts = mesh.vertices.tolist()
        faces = mesh.faces.tolist()
        normals = self._face_normals(verts, faces)
        return {"vertices": verts, "faces": faces, "normals": normals}

    def _scene_dict(self) -> dict:
        return {"objects": list(self._objects.values())}

    def _emit_scene(self) -> str:
        return json.dumps(self._scene_dict())

    # ---- Primitive creation ----

    @Slot(str, result=str)
    def newScene(self):
        self._objects = {}
        self._next_id = 0
        return self._emit_scene()

    @Slot(str, str, result=str)
    def addPrimitive(self, name: str, jsonParams: str) -> str:
        try:
            params = json.loads(jsonParams)
        except (json.JSONDecodeError, TypeError):
            params = {}
        shape = params.get("type", "cube")
        size = params.get("size", 2)
        radius = params.get("radius", 1.5)
        height = params.get("height", 3)
        major_r = params.get("major_radius", 2)
        minor_r = params.get("minor_radius", 0.8)

        if shape == "cube":
            m = trimesh.creation.box(extents=[size, size, size])
        elif shape == "sphere":
            m = trimesh.creation.icosphere(subdivisions=2, radius=radius)
        elif shape == "cylinder":
            m = trimesh.creation.cylinder(radius=radius, height=height, sections=24)
        elif shape == "cone":
            m = trimesh.creation.cone(radius=radius, height=height, sections=24)
        elif shape == "torus":
            m = trimesh.creation.torus(major_radius=major_r, minor_radius=minor_r, major_sections=24, minor_sections=16)
        elif shape == "pyramid":
            m = self._make_pyramid(size, height)
        else:
            return json.dumps({"error": f"Unknown shape: {shape}"})

        geom = self._mesh_to_geom(m)
        obj_id = self._new_id()
        self._objects[obj_id] = {
            "id": obj_id,
            "name": name or shape.capitalize(),
            "color": self._next_color(),
            "visible": True,
            "mesh": geom,
            "transform": {"position": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1]}
        }
        return self._emit_scene()

    def _make_pyramid(self, base, height):
        s = base / 2
        h = height / 2
        verts = np.array([
            [0, 0, h], [-s, -s, -h], [s, -s, -h],
            [s, s, -h], [-s, s, -h]
        ], dtype=float)
        faces = np.array([
            [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1],
            [1, 4, 3], [1, 3, 2]
        ])
        m = trimesh.Trimesh(vertices=verts, faces=faces)
        m.fix_normals()
        return m

    # ---- Scene management ----

    @Slot(result=str)
    def getSceneJson(self):
        return self._emit_scene()

    @Slot(str, result=str)
    def removeObject(self, objId: str) -> str:
        if objId in self._objects:
            del self._objects[objId]
        return self._emit_scene()

    @Slot(str, result=str)
    def duplicateObject(self, objId: str) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        src = self._objects[objId]
        new_id = self._new_id()
        self._objects[new_id] = {
            "id": new_id,
            "name": src["name"] + "_copy",
            "color": self._next_color(),
            "visible": True,
            "mesh": {
                "vertices": [list(v) for v in src["mesh"]["vertices"]],
                "faces": [list(f) for f in src["mesh"]["faces"]],
                "normals": [list(n) for n in src["mesh"].get("normals", [])]
            },
            "transform": {
                "position": [src["transform"]["position"][0] + 1.5,
                             src["transform"]["position"][1],
                             src["transform"]["position"][2]],
                "rotation": list(src["transform"]["rotation"]),
                "scale": list(src["transform"]["scale"])
            }
        }
        return self._emit_scene()

    @Slot(str, str, result=str)
    def renameObject(self, objId: str, newName: str) -> str:
        if objId in self._objects:
            self._objects[objId]["name"] = newName
        return self._emit_scene()

    @Slot(str, str, result=str)
    def setObjectColor(self, objId: str, hexColor: str) -> str:
        if objId in self._objects:
            self._objects[objId]["color"] = hexColor
        return self._emit_scene()

    @Slot(str, bool, result=str)
    def setObjectVisible(self, objId: str, visible: bool) -> str:
        if objId in self._objects:
            self._objects[objId]["visible"] = visible
        return self._emit_scene()

    @Slot(str, float, float, float, result=str)
    def setObjectPosition(self, objId: str, x: float, y: float, z: float) -> str:
        if objId in self._objects:
            self._objects[objId]["transform"]["position"] = [x, y, z]
        return self._emit_scene()

    @Slot(str, float, float, float, result=str)
    def setObjectRotation(self, objId: str, x: float, y: float, z: float) -> str:
        if objId in self._objects:
            self._objects[objId]["transform"]["rotation"] = [x, y, z]
        return self._emit_scene()

    @Slot(str, float, float, float, result=str)
    def setObjectScale(self, objId: str, x: float, y: float, z: float) -> str:
        if objId in self._objects:
            self._objects[objId]["transform"]["scale"] = [x, y, z]
        return self._emit_scene()

    @Slot(str, str, str, result=str)
    def rayPick(self, sceneJson: str, rayOriginStr: str, rayDirStr: str) -> str:
        scene = json.loads(sceneJson)
        ro = np.array(json.loads(rayOriginStr), dtype=float)
        rd = np.array(json.loads(rayDirStr), dtype=float)
        nd = np.linalg.norm(rd)
        if nd < 1e-10:
            return json.dumps({"hit": False})
        rd = rd / nd

        closest_dist = float("inf")
        result = {"hit": False}

        def euler_rotmat(e):
            cx, sx = math.cos(e[0]), math.sin(e[0])
            cy, sy = math.cos(e[1]), math.sin(e[1])
            cz, sz = math.cos(e[2]), math.sin(e[2])
            return np.array([
                [cy * cz, cz * sx * sy - cx * sz, sx * sz + cx * cz * sy],
                [cy * sz, cx * cz + sx * sy * sz, cx * sy * sz - cz * sx],
                [-sy, cy * sx, cx * cy]
            ])

        def mt_intersect(o, d, v0, v1, v2):
            eps = 1e-8
            e1 = v1 - v0
            e2 = v2 - v0
            h = np.cross(d, e2)
            a = np.dot(e1, h)
            if -eps < a < eps:
                return False, 0, None
            f = 1.0 / a
            s = o - v0
            u = f * np.dot(s, h)
            if u < 0.0 or u > 1.0:
                return False, 0, None
            q = np.cross(s, e1)
            v = f * np.dot(d, q)
            if v < 0.0 or u + v > 1.0:
                return False, 0, None
            t = f * np.dot(e2, q)
            if t > eps:
                return True, t, o + d * t
            return False, 0, None

        for obj in scene.get("objects", []):
            if not obj.get("visible", True):
                continue
            verts = np.array(obj["mesh"]["vertices"], dtype=float)
            faces = np.array(obj["mesh"]["faces"])
            tf = obj.get("transform", {})
            pos = np.array(tf.get("position", [0, 0, 0]), dtype=float)
            rot = np.array(tf.get("rotation", [0, 0, 0]), dtype=float)
            scl = np.array(tf.get("scale", [1, 1, 1]), dtype=float)

            R = euler_rotmat(rot)
            wverts = verts * scl
            wverts = wverts @ R.T
            wverts = wverts + pos

            for fi, face in enumerate(faces):
                v0, v1, v2 = wverts[face[0]], wverts[face[1]], wverts[face[2]]
                hit, dist, pt = mt_intersect(ro, rd, v0, v1, v2)
                if hit and dist < closest_dist:
                    closest_dist = dist
                    result = {
                        "hit": True,
                        "objectId": obj["id"],
                        "faceIndex": fi,
                        "point": pt.tolist(),
                        "distance": dist
                    }

        return json.dumps(result)

    # ---- Mesh operations ----

    @Slot(str, int, float, result=str)
    def extrudeFace(self, objId: str, faceIndex: int, distance: float) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        obj = self._objects[objId]
        verts = np.array(obj["mesh"]["vertices"], dtype=float)
        faces = np.array(obj["mesh"]["faces"])

        if faceIndex < 0 or faceIndex >= len(faces):
            return self._emit_scene()

        face = faces[faceIndex]
        v0, v1, v2 = verts[face[0]], verts[face[1]], verts[face[2]]
        normal = np.cross(v1 - v0, v2 - v0)
        nd = np.linalg.norm(normal)
        if nd > 1e-10:
            normal = normal / nd

        new_verts_list = verts.tolist()
        nv = len(new_verts_list)
        extruded_indices = []
        for vi in face:
            new_verts_list.append((verts[vi] + normal * distance).tolist())
            extruded_indices.append(nv)
            nv += 1

        new_faces_list = faces.tolist()
        new_faces_list.pop(faceIndex)
        for i in range(len(face)):
            a = face[i]
            b = face[(i + 1) % len(face)]
            ai = extruded_indices[i]
            bi = extruded_indices[(i + 1) % len(face)]
            new_faces_list.append([a, b, bi])
            new_faces_list.append([a, bi, ai])
        new_faces_list.append(extruded_indices)

        try:
            m = trimesh.Trimesh(vertices=np.array(new_verts_list), faces=np.array(new_faces_list))
            m.fix_normals()
            m.merge_vertices(0.001)
            obj["mesh"] = self._mesh_to_geom(m)
        except Exception:
            pass
        return self._emit_scene()

    @Slot(str, int, result=str)
    def subdivideObject(self, objId: str, iterations: int) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        obj = self._objects[objId]
        verts = np.array(obj["mesh"]["vertices"], dtype=float)
        faces = np.array(obj["mesh"]["faces"])

        for _ in range(iterations):
            try:
                verts, faces = trimesh.remesh.subdivide(verts, faces)
            except Exception:
                break

        try:
            m = trimesh.Trimesh(vertices=verts, faces=faces)
            m.fix_normals()
            obj["mesh"] = self._mesh_to_geom(m)
        except Exception:
            pass
        return self._emit_scene()

    @Slot(str, str, result=str)
    def deleteFaces(self, objId: str, jsonFaceIndices: str) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        obj = self._objects[objId]
        verts = np.array(obj["mesh"]["vertices"], dtype=float)
        faces = np.array(obj["mesh"]["faces"])
        indices = json.loads(jsonFaceIndices)

        mask = np.ones(len(faces), dtype=bool)
        for idx in indices:
            if 0 <= idx < len(faces):
                mask[idx] = False

        if not np.any(mask):
            return self._emit_scene()

        new_faces = faces[mask]
        try:
            m = trimesh.Trimesh(vertices=verts, faces=new_faces)
            m.remove_unreferenced_vertices()
            m.fix_normals()
            obj["mesh"] = self._mesh_to_geom(m)
        except Exception:
            pass
        return self._emit_scene()

    @Slot(str, float, result=str)
    def weldVertices(self, objId: str, tolerance: float) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        obj = self._objects[objId]
        verts = np.array(obj["mesh"]["vertices"], dtype=float)
        faces = np.array(obj["mesh"]["faces"])

        try:
            m = trimesh.Trimesh(vertices=verts, faces=faces)
            m.merge_vertices(tolerance)
            m.fix_normals()
            obj["mesh"] = self._mesh_to_geom(m)
        except Exception:
            pass
        return self._emit_scene()

    @Slot(str, float, float, float, result=str)
    def addVertex(self, objId: str, x: float, y: float, z: float) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        obj = self._objects[objId]
        obj["mesh"]["vertices"].append([x, y, z])
        obj["mesh"]["normals"] = self._face_normals(
            obj["mesh"]["vertices"], obj["mesh"]["faces"]
        )
        return self._emit_scene()

    @Slot(str, str, result=str)
    def addFace(self, objId: str, jsonIndices: str) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        obj = self._objects[objId]
        indices = json.loads(jsonIndices)
        verts = obj["mesh"]["vertices"]
        for idx in indices:
            if idx < 0 or idx >= len(verts):
                return self._emit_scene()

        obj["mesh"]["faces"].append(indices)
        obj["mesh"]["normals"] = self._face_normals(
            obj["mesh"]["vertices"], obj["mesh"]["faces"]
        )
        return self._emit_scene()

    @Slot(str, int, result=str)
    def removeVertex(self, objId: str, vertexIndex: int) -> str:
        if objId not in self._objects:
            return self._emit_scene()
        obj = self._objects[objId]
        verts = np.array(obj["mesh"]["vertices"], dtype=float)
        faces = np.array(obj["mesh"]["faces"])

        new_faces = []
        for f in faces:
            if vertexIndex not in f:
                new_verts_set = set(f)
                if len(new_verts_set) == 3:
                    new_faces.append(f.tolist())

        try:
            kept = [i for i in range(len(verts)) if i != vertexIndex]
            vmap = {old: new for new, old in enumerate(kept)}
            remapped = []
            for f in new_faces:
                remapped.append([vmap[vi] for vi in f])
            if remapped:
                m = trimesh.Trimesh(
                    vertices=np.array([verts[i] for i in kept], dtype=float),
                    faces=np.array(remapped)
                )
                m.fix_normals()
                obj["mesh"] = self._mesh_to_geom(m)
        except Exception:
            pass
        return self._emit_scene()

    # ---- Import / Export ----

    @Slot(str, result=str)
    def importMesh(self, filePath: str) -> str:
        if not os.path.isfile(filePath):
            return json.dumps({"error": "File not found"})
        try:
            m = trimesh.load(filePath)
            if isinstance(m, trimesh.Scene):
                meshes = list(m.geometry.values())
                if not meshes:
                    return json.dumps({"error": "No geometry in scene"})
                m = meshes[0]
            m.fix_normals()
            geom = self._mesh_to_geom(m)
            return json.dumps(geom)
        except Exception as e:
            return json.dumps({"error": str(e)})

    @Slot(str, str, str, result=bool)
    def exportMesh(self, objId: str, filePath: str, fileFormat: str) -> bool:
        if objId not in self._objects:
            return False
        obj = self._objects[objId]
        try:
            m = trimesh.Trimesh(
                vertices=np.array(obj["mesh"]["vertices"]),
                faces=np.array(obj["mesh"]["faces"])
            )
            m.export(filePath, file_type=fileFormat)
            return True
        except Exception:
            return False

    @Slot(str, str, result=str)
    def addImportedObject(self, name: str, geomJson: str) -> str:
        geom = json.loads(geomJson)
        if "error" in geom:
            return self._emit_scene()
        obj_id = self._new_id()
        self._objects[obj_id] = {
            "id": obj_id,
            "name": name,
            "color": self._next_color(),
            "visible": True,
            "mesh": geom,
            "transform": {"position": [0, 0, 0], "rotation": [0, 0, 0], "scale": [1, 1, 1]}
        }
        return self._emit_scene()

    # ---- Face normals query ----

    @Slot(str, result=str)
    def getFaceNormals(self, objId: str) -> str:
        if objId not in self._objects:
            return json.dumps([])
        obj = self._objects[objId]
        return json.dumps(obj["mesh"].get("normals", []))
