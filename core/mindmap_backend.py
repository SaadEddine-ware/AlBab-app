import json
import os
import re
import math
import threading
from collections import Counter, defaultdict
from urllib.parse import urlparse, unquote

from PySide6.QtCore import QObject, Signal, Slot

import time

try:
    from openai import OpenAI
    import httpx
    _HAS_OPENAI = True
except ImportError:
    _HAS_OPENAI = False


_MINDMAP_PROMPT = (
    "You are an expert knowledge organizer. Analyze the following text and create a comprehensive, "
    "hierarchical mind map structure.\n\n"
    "Return a JSON object with this exact structure:\n"
    "{{\n"
    '  "id": "root",\n'
    '  "label": "Main Topic",\n'
    '  "description": "A 1-2 sentence overview of the entire topic",\n'
    '  "children": [\n'
    "    {{\n"
    '      "id": "branch_1",\n'
    '      "label": "Branch Name",\n'
    '      "description": "Brief explanation of this branch",\n'
    '      "children": [\n'
    "        {{\n"
    '          "id": "leaf_1_1",\n'
    '          "label": "Sub-concept",\n'
    '          "description": "Brief explanation",\n'
    '          "children": []\n'
    "        }}\n"
    "      ]\n"
    "    }}\n"
    "  ]\n"
    "}}\n\n"
    "Rules:\n"
    "- Root node: the overarching topic (1 node)\n"
    "- Level 1 (main branches): 3-6 key themes or categories\n"
    "- Level 2: 2-4 sub-concepts per branch\n"
    "- Level 3 (optional): 1-3 specific details per sub-concept\n"
    "- Each node MUST have: id, label, description, children\n"
    "- Labels should be SHORT (2-5 words), descriptions 1-2 sentences\n"
    "- Use clear, specific concepts — not vague categories\n"
    "- Capture relationships and hierarchies accurately\n"
    "- Return ONLY valid JSON, no markdown code fences, no extra text\n\n"
    "Text:\n{text}"
)

_FREE_PROVIDERS = [
    {
        "name": "Groq",
        "base_url": "https://api.groq.com/openai/v1",
        "model": "llama-3.3-70b-versatile",
        "api_key": "",
        "env_key": "GROQ_API_KEY",
    },
]

_BRANCH_COLORS = [
    "#E74C3C",  # Red
    "#3498DB",  # Blue
    "#2ECC71",  # Green
    "#F39C12",  # Orange
    "#9B59B6",  # Purple
    "#1ABC9C",  # Teal
    "#E67E22",  # Dark Orange
    "#E84393",  # Pink
]


def _tokenize(text):
    return re.findall(r"[a-zA-Z\u0600-\u06FF]{3,}", text.lower())


def _sentences(text):
    raw = re.split(r'[.!?;:\n]+', text)
    return [s.strip() for s in raw if len(s.strip()) > 10]


def _tfidf_keywords(text, top_n=30):
    _STOP_WORDS = {
        "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "shall", "can", "to", "of", "in", "for",
        "on", "with", "at", "by", "from", "as", "into", "through", "during",
        "before", "after", "and", "but", "or", "if", "because", "that",
        "this", "these", "those", "it", "its", "they", "them", "their",
        "what", "which", "who", "he", "she", "him", "her", "his", "my",
        "your", "our", "we", "you", "me", "us", "about", "up", "not",
        "no", "nor", "only", "own", "same", "so", "than", "too", "very",
        "just", "now", "also", "all", "both", "each", "few", "more",
        "most", "other", "some", "such", "here", "there", "when", "where",
        "why", "how",
    }
    sentences = _sentences(text)
    if not sentences:
        return []

    doc_freq = Counter()
    word_freq = Counter()

    for sent in sentences:
        words = [w for w in _tokenize(sent) if w not in _STOP_WORDS]
        for w in set(words):
            doc_freq[w] += 1
        word_freq.update(words)

    total_docs = len(sentences)
    scores = {}
    for word, freq in word_freq.items():
        tf = freq / max(len(word_freq), 1)
        idf = math.log(1 + total_docs / max(doc_freq[word], 1))
        scores[word] = tf * idf

    ranked = sorted(scores.items(), key=lambda x: x[1], reverse=True)
    return [w for w, s in ranked[:top_n]]


def _find_root_topic(keywords, text):
    """Find the most representative root topic from the text."""
    sentences = _sentences(text)
    if not sentences or not keywords:
        return "Document"

    # Look for the most frequent keyword that appears in the first few sentences
    keyword_set = set(keywords[:10])
    first_sentences = sentences[:min(3, len(sentences))]
    title_words = Counter()

    for sent in first_sentences:
        words = [w for w in _tokenize(sent) if w in keyword_set]
        title_words.update(words)

    if title_words:
        best = title_words.most_common(1)[0][0]
        return best.title()

    return keywords[0].title() if keywords else "Document"


def _build_tree(text, keywords):
    if not keywords:
        return {"id": "root", "label": "Document", "description": "", "children": []}

    sentences = _sentences(text)
    keyword_set = set(keywords)

    sentence_keywords = []
    for sent in sentences:
        words = [w for w in _tokenize(sent) if w in keyword_set]
        sentence_keywords.append(words)

    # Build co-occurrence matrix
    co_occur = defaultdict(int)
    for sw in sentence_keywords:
        for i, w1 in enumerate(sw):
            for w2 in sw[i+1:]:
                co_occur[(w1, w2)] += 1
                co_occur[(w2, w1)] += 1

    # Select top keywords as branch leaders
    n_branches = min(6, max(3, len(keywords) // 4))
    branch_leaders = keywords[:n_branches]

    # Assign remaining keywords to branches by co-occurrence strength
    assigned = set(branch_leaders)
    branches = {}

    for leader in branch_leaders:
        branches[leader] = []

    for kw in keywords[n_branches:]:
        best_leader = max(branch_leaders, key=lambda l: co_occur.get((l, kw), 0))
        if co_occur.get((best_leader, kw), 0) > 0:
            branches[best_leader].append(kw)
            assigned.add(kw)

    # Build the tree with descriptions
    root_topic = _find_root_topic(keywords, text)

    # Create a brief description for root
    root_desc = _make_description(root_topic, sentences, keyword_set)

    children = []
    for i, topic in enumerate(branch_leaders):
        branch_desc = _make_description(topic, sentences, keyword_set)
        topic_children = []

        for kw in branches[topic]:
            kw_desc = _make_description(kw, sentences, keyword_set)
            topic_children.append({
                "id": f"leaf_{kw}_{i}",
                "label": kw.title(),
                "description": kw_desc,
                "children": []
            })

        children.append({
            "id": f"branch_{topic}_{i}",
            "label": topic.title(),
            "description": branch_desc,
            "children": topic_children
        })

    return {
        "id": "root",
        "label": root_topic,
        "description": root_desc,
        "children": children
    }


def _make_description(keyword, sentences, keyword_set):
    """Extract a brief description for a keyword by finding the most relevant sentence."""
    best_sent = ""
    best_score = 0

    kw_lower = keyword.lower()
    for sent in sentences:
        words = _tokenize(sent)
        if kw_lower in words:
            # Score by how many other keywords also appear (topic relevance)
            overlap = len([w for w in words if w in keyword_set])
            if overlap > best_score:
                best_score = overlap
                best_sent = sent

    if best_sent:
        # Truncate to a reasonable length
        if len(best_sent) > 120:
            # Try to end at a natural break
            truncated = best_sent[:117]
            last_space = truncated.rfind(" ")
            if last_space > 40:
                truncated = truncated[:last_space]
            return truncated + "..."
        return best_sent

    return ""


def _parse_ai_json(text):
    raw = text.strip()
    # Remove markdown code fences if present
    if raw.startswith("```"):
        lines = raw.split("\n")
        lines = [l for l in lines if not l.strip().startswith("```")]
        raw = "\n".join(lines)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        # Try to find JSON object in the response
        match = re.search(r'\{[\s\S]*\}', raw)
        if match:
            try:
                return json.loads(match.group())
            except json.JSONDecodeError:
                pass
        return None


def _assign_branch_colors(tree):
    """Assign colors to top-level branches for visual distinction."""
    if not tree or "children" not in tree:
        return tree

    for i, child in enumerate(tree["children"]):
        color_index = i % len(_BRANCH_COLORS)
        child["color"] = _BRANCH_COLORS[color_index]
        # Propagate color to all descendants
        _propagate_color(child, _BRANCH_COLORS[color_index])

    return tree


def _propagate_color(node, color):
    if "children" in node:
        for child in node["children"]:
            child["color"] = color
            _propagate_color(child, color)


class MindMapBackend(QObject):
    mindMapReady = Signal(str)
    errorOccurred = Signal(str)
    statusChanged = Signal(str)
    nodeCountChanged = Signal(int)

    def __init__(self, key_rotation=None, parent=None):
        super().__init__(parent)
        self._key_rotation = key_rotation
        self._gemini_client = None
        self._selected_provider = "auto"
        self._generation_done = False
        self._gen_id = 0
        self._timeout_timer = None
        self._api_key = self._resolve_key()
        if self._api_key:
            self._init_gemini()

    @Slot(str)
    def setProvider(self, provider):
        self._selected_provider = provider.lower()
        # Re-initialize Gemini client when switching to gemini provider
        if self._selected_provider == "gemini":
            self._api_key = self._resolve_key()
            if self._api_key:
                self._init_gemini()

    def _resolve_key(self) -> str:
        if self._key_rotation and self._key_rotation.has_keys:
            return self._key_rotation.current
        return ""

    def _init_gemini(self):
        try:
            from google import genai
            from google.genai import types
            self._gemini_client = genai.Client(
                api_key=self._api_key,
                http_options=types.HttpOptions(timeout=30)
            )
        except Exception:
            self._gemini_client = None

    def _resolve_path(self, file_path):
        if file_path.startswith("file:///"):
            parsed = urlparse(file_path)
            path = unquote(parsed.path)
            if os.name == "nt" and path.startswith("/"):
                path = path[1:]
            return path
        return file_path

    @Slot(str)
    def generateFromText(self, text):
        if not text or not text.strip():
            self.errorOccurred.emit("No text provided")
            return

        self._generation_done = False
        self._gen_id += 1
        gen_id = self._gen_id
        self.statusChanged.emit("generating")
        if self._timeout_timer:
            self._timeout_timer.cancel()
        timer = threading.Timer(60.0, self._force_timeout)
        timer.daemon = True
        self._timeout_timer = timer
        timer.start()
        thread = threading.Thread(target=self._generate_thread, args=(text, gen_id), daemon=True)
        thread.start()

    def _force_timeout(self):
        if self._generation_done:
            return
        self._generation_done = True
        self.errorOccurred.emit("Generation timed out - try again or use local mode")
        self.statusChanged.emit("idle")
        if self._timeout_timer:
            self._timeout_timer.cancel()
            self._timeout_timer = None

    @Slot(str)
    def generateFromPdf(self, file_path):
        file_path = self._resolve_path(file_path)
        try:
            import PyPDF2
            if not os.path.isfile(file_path):
                self.errorOccurred.emit(f"File not found: {os.path.basename(file_path)}")
                return
            with open(file_path, 'rb') as f:
                reader = PyPDF2.PdfReader(f)
                text = ""
                for page in reader.pages:
                    text += page.extract_text() or ""
            if not text.strip():
                self.errorOccurred.emit("Could not extract text from PDF")
                return
            self.generateFromText(text)
        except ImportError:
            self.errorOccurred.emit("PyPDF2 not installed. Run: pip install PyPDF2")
        except Exception as e:
            self.errorOccurred.emit(f"Failed to read PDF: {str(e)}")

    @Slot(str)
    def generateFromFile(self, file_path):
        file_path = self._resolve_path(file_path)
        try:
            if not os.path.isfile(file_path):
                self.errorOccurred.emit(f"File not found: {os.path.basename(file_path)}")
                return
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                text = f.read()
            if not text.strip():
                self.errorOccurred.emit("File is empty")
                return
            self.generateFromText(text)
        except Exception as e:
            self.errorOccurred.emit(f"Failed to read file: {str(e)}")

    def _emit_result(self, result, gen_id):
        """Emit the result if gen_id is still current. Returns True if emitted."""
        if gen_id != self._gen_id:
            return False
        result = _assign_branch_colors(result)
        self.mindMapReady.emit(json.dumps(result))
        self.nodeCountChanged.emit(self._count_nodes(result))
        return True

    def _generate_thread(self, text, gen_id):
        if gen_id != self._gen_id:
            return
        try:
            # Use more text for better context (increased from 8000)
            prompt = _MINDMAP_PROMPT.format(text=text[:15000])

            if self._selected_provider == "gemini":
                result = self._try_gemini(prompt, gen_id)
                if result and self._emit_result(result, gen_id):
                    return
                self.statusChanged.emit("Generating locally...")
                result = self._local_extract(text)
                self._emit_result(result, gen_id)
                return

            elif self._selected_provider == "groq":
                if gen_id != self._gen_id:
                    return
                result = self._try_openai_provider(_FREE_PROVIDERS[0], prompt)
                if result and self._emit_result(result, gen_id):
                    return
                self.statusChanged.emit("Generating locally...")
                result = self._local_extract(text)
                self._emit_result(result, gen_id)
                return

            else:  # auto mode — Groq only, no Gemini
                for provider in _FREE_PROVIDERS:
                    if gen_id != self._gen_id:
                        return
                    self.statusChanged.emit(f"Trying {provider['name']}...")
                    result = self._try_openai_provider(provider, prompt)
                    if result and self._emit_result(result, gen_id):
                        return

                # Local fallback
                self.statusChanged.emit("Generating locally...")
                result = self._local_extract(text)
                self._emit_result(result, gen_id)

        except Exception as e:
            if gen_id == self._gen_id:
                self.errorOccurred.emit(f"Error: {str(e)}")
        finally:
            if gen_id == self._gen_id:
                self._generation_done = True
                self.statusChanged.emit("idle")
            if self._timeout_timer:
                self._timeout_timer.cancel()
                self._timeout_timer = None

    def _try_gemini(self, prompt, gen_id=None):
        # Always re-read the latest key from rotation (may have changed)
        self._api_key = self._resolve_key()
        if not self._api_key:
            return None
        # Re-init client with fresh key if needed
        self._init_gemini()
        if not self._gemini_client:
            return None

        self.statusChanged.emit("Trying Gemini AI...")
        last_error = ""
        try:
            from google.api_core.exceptions import ResourceExhausted

            for attempt in range(3):
                if gen_id is not None and gen_id != self._gen_id:
                    return None
                try:
                    response = self._gemini_client.models.generate_content(
                        model="gemini-2.0-flash",
                        contents=prompt
                    )
                    if response and response.text:
                        result = _parse_ai_json(response.text)
                        if result and "children" in result:
                            return result
                        last_error = "Gemini response could not be parsed as mind map"
                    else:
                        last_error = "Gemini returned empty response"
                    return None
                except ResourceExhausted:
                    if self._key_rotation and self._key_rotation.has_keys:
                        self._key_rotation.mark_failure()
                        self._key_rotation.rotate()
                        self._api_key = self._key_rotation.current
                        self._init_gemini()
                    time.sleep(1 * (2 ** attempt))
                except Exception as e:
                    last_error = f"Gemini error: {str(e)[:80]}"
                    break
        except Exception as e:
            last_error = f"Gemini init error: {str(e)[:80]}"
        return None

    def _try_openai_provider(self, provider, prompt):
        api_key = provider.get("api_key", "") or os.environ.get(provider.get("env_key", ""), "")
        if not api_key or not _HAS_OPENAI:
            return None

        try:
            timeout_kwargs = {}
            if 'httpx' in dir():
                timeout_kwargs["timeout"] = httpx.Timeout(15.0, connect=5.0)
            client = OpenAI(
                api_key=api_key,
                base_url=provider["base_url"],
                **timeout_kwargs
            )
            response = client.chat.completions.create(
                model=provider["model"],
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3,
            )

            if response and response.choices:
                content = response.choices[0].message.content
                if content:
                    result = _parse_ai_json(content)
                    if result and "children" in result:
                        return result
        except Exception as e:
            self.statusChanged.emit(f"{provider['name']} failed: {str(e)[:60]}")
        return None

    def _count_nodes(self, tree):
        """Count total nodes in the tree."""
        if not tree:
            return 0
        count = 1
        for child in tree.get("children", []):
            count += self._count_nodes(child)
        return count

    def _local_extract(self, text):
        try:
            keywords = _tfidf_keywords(text, top_n=25)
            if not keywords:
                return {"id": "root", "label": "Document", "description": "Could not extract keywords", "children": []}
            return _build_tree(text, keywords)
        except Exception as e:
            return {"id": "root", "label": "Document", "description": f"Local extraction error: {str(e)[:80]}", "children": []}