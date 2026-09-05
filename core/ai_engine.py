# NOTE: Unused dead code. Kept for reference only.
# No instantiation or registration exists anywhere in the app.
class AiEngine:
    def __init__(self, model_name="Llama 3.2", provider="ollama"):
        self.model_name = model_name
        self.provider = provider
        self._available_models = [
            {"name": "Llama 3.2", "desc": "Meta 8B instruct", "status": "running"},
            {"name": "Mistral 7B", "desc": "Mistral AI v0.3", "status": "running"},
            {"name": "Phi-3 Mini", "desc": "Microsoft 3.8B", "status": "stopped"},
            {"name": "Gemma 2B", "desc": "Google 2B it", "status": "downloading"},
            {"name": "Qwen 1.5B", "desc": "Alibaba 1.5B", "status": "not_installed"},
            {"name": "DeepSeek Coder", "desc": "Code-specialized", "status": "not_installed"},
        ]

    def get_models(self):
        return self._available_models

    def chat(self, message, model_name=None):
        return f"[{model_name or self.model_name}] Echo: {message}"

    def summarize(self, text):
        lines = text.strip().split("\n")
        return f"Summary: {min(len(lines), 5)} key points identified."
